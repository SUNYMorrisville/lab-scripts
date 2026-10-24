# src\Tasks\Set-StaticIP.ps1
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "..\Lib\Logging.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "..\Lib\Validation.psm1") -Force

Initialize-LabLog
Assert-IsAdmin

function Wait-MenuContinue {
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Prompt-NonEmpty([string]$label, [string]$default) {
    $v = Read-Host "$label [$default]"
    if ([string]::IsNullOrWhiteSpace($v)) { return $default }
    return $v.Trim()
}

function Prompt-Int([string]$label, [int]$default) {
    while ($true) {
        $v = Read-Host "$label [$default]"
        if ([string]::IsNullOrWhiteSpace($v)) { return $default }
        $n = 0
        if ([int]::TryParse($v.Trim(), [ref]$n)) { return $n }
        Write-Host "Please enter a valid number."
    }
}

function Select-NetworkAdapter {
    $adapters = @(Get-NetAdapter |
        Where-Object { $_.Status -eq "Up" } |
        Sort-Object -Property Name)

    if ($adapters.Count -lt 1) {
        throw "No active network adapters found."
    }

    Write-Host ""
    Write-Host "Active network adapters:"
    for ($i = 0; $i -lt $adapters.Count; $i++) {
        $a = $adapters[$i]
        Write-Host ("{0}) {1}  (InterfaceIndex: {2}, Status: {3})" -f ($i + 1), $a.Name, $a.IfIndex, $a.Status)
    }

    while ($true) {
        $choice = Read-Host "Select adapter (1-$($adapters.Count))"
        $n = 0
        if ([int]::TryParse($choice, [ref]$n) -and $n -ge 1 -and $n -le $adapters.Count) {
            return $adapters[$n - 1]
        }
        Write-Host "Invalid selection."
    }
}

function Test-ValidIPv4([string]$value) {
    # Dotted quad only. The round-trip check rejects forms TryParse would otherwise
    # accept: shorthand ("192.168.1" -> 192.168.0.1), integers, hex, and leading zeros (octal).
    if ($value -cnotmatch '^[0-9]{1,3}(\.[0-9]{1,3}){3}$') { return $false }
    $parsed = $null
    if (-not [System.Net.IPAddress]::TryParse($value, [ref]$parsed)) { return $false }
    if ($parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { return $false }
    if ($parsed.ToString() -ne $value) { return $false }
    if ($value -eq "0.0.0.0" -or $value -eq "255.255.255.255") { return $false }
    return $true
}

function Assert-ValidIPv4([string]$label, [string]$value) {
    if (-not (Test-ValidIPv4 $value)) {
        throw "'$value' is not a valid IPv4 address for $label."
    }
}

function Get-IPv4Int64([string]$value) {
    $b = ([System.Net.IPAddress]::Parse($value)).GetAddressBytes()
    return ([int64]$b[0] * 16777216) + ([int64]$b[1] * 65536) + ([int64]$b[2] * 256) + [int64]$b[3]
}

function Assert-GatewayInSubnet([string]$ipAddr, [int]$prefixLength, [string]$gateway) {
    $blockSize = [int64][math]::Pow(2, 32 - $prefixLength)
    $ipInt     = Get-IPv4Int64 $ipAddr
    $gwInt     = Get-IPv4Int64 $gateway
    $network   = $ipInt - ($ipInt % $blockSize)
    $broadcast = $network + $blockSize - 1

    # /31 and /32 have no separate network/broadcast addresses
    if ($prefixLength -le 30 -and ($ipInt -eq $network -or $ipInt -eq $broadcast)) {
        throw "'$ipAddr' is the network or broadcast address of its /$prefixLength subnet."
    }
    if ($gwInt -lt $network -or $gwInt -gt $broadcast) {
        throw "Default gateway '$gateway' is not in the $ipAddr/$prefixLength subnet."
    }
    if ($gwInt -eq $ipInt -or ($prefixLength -le 30 -and ($gwInt -eq $network -or $gwInt -eq $broadcast))) {
        throw "Default gateway '$gateway' is not a usable host address in the $ipAddr/$prefixLength subnet."
    }
}

function Test-IPv4InUse([string]$ip) {
    # Best-effort: if it answers ping, assume it's in use.
    # (Not perfect—some hosts block ICMP—but good enough to prevent common lab collisions.)
    try {
        return (Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction Stop)
    } catch {
        return $false
    }
}

Write-Host ""
Write-Host "Configure Static IPv4 Address"
Write-Host "----------------------------"

$adapter = Select-NetworkAdapter
Write-LabLog "StaticIP: Selected adapter $($adapter.Name) (IfIndex $($adapter.IfIndex))"

# Basic lab defaults
$defaultPrefix  = 24
$defaultGateway = "192.168.1.1"

# Role-based defaults to avoid the 192.168.1.2 duplicate problem
Write-Host ""
Write-Host "Select machine type (for safer defaults):"
Write-Host "1) Domain Controller (DC)  - typically 192.168.1.2"
Write-Host "2) Member Server           - typically 192.168.1.3+"
Write-Host "3) Windows Client          - typically 192.168.1.50+"
$role = Read-Host "Choice [3]"

if ([string]::IsNullOrWhiteSpace($role)) { $role = "3" }

$defaultIp = switch ($role.Trim()) {
    "1" { "192.168.1.2" }
    "2" { "192.168.1.3" }
    default { "192.168.1.50" }
}

$ip      = Prompt-NonEmpty "IP address" $defaultIp
$prefix  = Prompt-Int "Prefix length (CIDR, e.g., 24)" $defaultPrefix
$gw      = Prompt-NonEmpty "Default gateway" $defaultGateway

# DNS default: if DC, use itself; otherwise use DC (.2) unless the user overrides
$defaultDns = if ($role.Trim() -eq "1") { $ip } else { "192.168.1.2" }
$dnsInput  = Prompt-NonEmpty "DNS server (primary)" $defaultDns
$dns2Raw   = Read-Host "DNS server (secondary, leave blank to skip)"
$dns2Input = $dns2Raw.Trim()

Assert-ValidIPv4 "IP address" $ip
if ($prefix -lt 1 -or $prefix -gt 32) {
    throw "Prefix length $prefix is out of range. Enter a value from 1 to 32 (e.g., 24)."
}
Assert-ValidIPv4 "Default gateway" $gw
Assert-GatewayInSubnet $ip $prefix $gw
Assert-ValidIPv4 "DNS server (primary)" $dnsInput
if ($dns2Input -ne "") { Assert-ValidIPv4 "DNS server (secondary)" $dns2Input }

$dnsServers = if ($dns2Input -ne "") { @($dnsInput, $dns2Input) } else { @($dnsInput) }

Write-Host ""
Write-Host "Summary:"
Write-Host " Adapter: $($adapter.Name)"
Write-Host " IP:      $ip/$prefix"
Write-Host " Gateway: $gw"
Write-Host " DNS:     $($dnsServers -join ', ')"
Write-Host ""

$confirm = Read-Host "Apply these settings? (Y/N)"
if ($confirm.Trim().ToUpper() -ne "Y") {
    Write-LabLog "StaticIP: User cancelled"
    Write-Host "Cancelled."
    Wait-MenuContinue
    return
}

# Duplicate / in-use check (skipped when this adapter already holds the address,
# since it would answer its own ping - e.g., converting a DHCP lease to static)
Write-Host ""
$inUse = $false
$alreadyAssigned = Get-NetIPAddress -InterfaceIndex $adapter.IfIndex -IPAddress $ip -AddressFamily IPv4 -ErrorAction SilentlyContinue
if ($alreadyAssigned) {
    Write-Host "$ip is already assigned to this adapter; skipping in-use check."
}
else {
    Write-Host "Checking if $ip is already in use..."
    $inUse = Test-IPv4InUse -ip $ip
}
if ($inUse) {
    Write-Host "WARNING: $ip responded to ping. It may already be in use."
    Write-Host "Pick a different IP to avoid a duplicate-address conflict."
    Write-LabLog "StaticIP: Aborted - IP appears in use ($ip)" "WARN"
    Wait-MenuContinue
    return
}

$ifIndex = $adapter.IfIndex

# Re-verify the adapter is still present and up — the user may have taken time
# reviewing the summary and the adapter state could have changed.
$verifiedAdapter = Get-NetAdapter -InterfaceIndex $ifIndex -ErrorAction SilentlyContinue
if ($null -eq $verifiedAdapter -or $verifiedAdapter.Status -ne "Up") {
    Write-Host "Adapter '$($adapter.Name)' is no longer available. Re-run and select an active adapter." -ForegroundColor Red
    Write-LabLog "StaticIP: Aborted - adapter $($adapter.Name) (IfIndex $ifIndex) no longer available" "WARN"
    Wait-MenuContinue
    return
}

# Apply. Everything below removes the current config first, so on any failure
# fall back to DHCP rather than leaving the adapter with no IPv4 address.
try {
    # Remove existing IPv4 addresses (except APIPA) to avoid duplicates
    $existing = Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "169.254.*" }

    foreach ($addr in $existing) {
        Write-LabLog "StaticIP: Removing existing IPv4 address $($addr.IPAddress)"
        Remove-NetIPAddress -InterfaceIndex $ifIndex -IPAddress $addr.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
    }

    # Remove default route(s) to prevent route conflicts
    $routes = Get-NetRoute -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" }

    foreach ($r in $routes) {
        Write-LabLog "StaticIP: Removing default route 0.0.0.0/0"
        Remove-NetRoute -InterfaceIndex $ifIndex -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue
    }

    Write-LabLog "StaticIP: Disabling DHCP on adapter $($adapter.Name)"
    Set-NetIPInterface -InterfaceIndex $ifIndex -Dhcp Disabled -ErrorAction Stop

    Write-LabLog "StaticIP: Setting IP $ip/$prefix GW $gw"
    New-NetIPAddress -InterfaceIndex $ifIndex -IPAddress $ip -PrefixLength $prefix -DefaultGateway $gw -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null

    Write-LabLog "StaticIP: Setting DNS server(s): $($dnsServers -join ', ')"
    Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $dnsServers -ErrorAction Stop
}
catch {
    $applyError = $_
    Write-Host ""
    Write-Host "Failed to apply static IP settings: $($applyError.Exception.Message)" -ForegroundColor Red
    Write-Host "Reverting adapter '$($adapter.Name)' to DHCP so it is not left without an address..." -ForegroundColor Yellow
    Write-LabLog "StaticIP: Apply failed ($($applyError.Exception.Message)) - reverting to DHCP" "ERROR"

    # Clear any partially applied static address/route, then hand the adapter back to DHCP
    Remove-NetIPAddress -InterfaceIndex $ifIndex -IPAddress $ip -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute -InterfaceIndex $ifIndex -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue
    try {
        Set-NetIPInterface -InterfaceIndex $ifIndex -Dhcp Enabled -ErrorAction Stop
        Write-Host "DHCP re-enabled on '$($adapter.Name)'. Check ipconfig /all, then re-run with corrected values." -ForegroundColor Yellow
        Write-LabLog "StaticIP: DHCP re-enabled on adapter $($adapter.Name)" "WARN"
    }
    catch {
        Write-Host "Could not re-enable DHCP: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Configure the adapter manually (ncpa.cpl) before continuing." -ForegroundColor Red
        Write-LabLog "StaticIP: Failed to re-enable DHCP ($($_.Exception.Message))" "ERROR"
    }

    throw $applyError
}

# Bounce adapter to apply cleanly
Write-LabLog "StaticIP: Restarting adapter $($adapter.Name)"
Restart-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Waiting for adapter to reinitialize..."
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "Static IP configuration applied."
Write-Host ("Log: {0}" -f (Get-LabLogPath))
Write-Host ""
ipconfig /all
Wait-MenuContinue
