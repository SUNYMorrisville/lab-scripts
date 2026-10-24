# src\Tasks\Client\GPO-Report.ps1
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "..\..\Lib\Logging.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "..\..\Lib\Validation.psm1") -Force

Initialize-LabLog

function Wait-MenuContinue {
    Write-Host ""
    Read-Host "Press Enter to continue"
}

Write-Host ""
Write-Host "Export Group Policy Report"
Write-Host "--------------------------"
Write-Host ""

try {
    $cs = Get-CimInstance Win32_ComputerSystem
    if (-not $cs.PartOfDomain) {
        Write-Host "This machine is not domain joined."
        Write-LabLog "GPO-Report: Aborted - not domain joined" "WARN"
        Wait-MenuContinue
        return
    }

    $desktop = [Environment]::GetFolderPath("Desktop")
    $file = Join-Path $desktop "GPO-Report.html"

    # /f overwrites an existing report (gpresult refuses to overwrite without it)
    gpresult /h $file /f | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "gpresult exited with code $LASTEXITCODE."
    }

    Write-Host "Report generated successfully."
    Write-Host ("Saved to: {0}" -f $file)
    Write-LabLog ("GPO-Report: Exported to {0}" -f $file)

}
catch {
    Write-Host ""
    Write-Host "Error exporting GPO report:"
    Write-Host $_.Exception.Message
    Write-LabLog ("GPO-Report: Failed - {0}" -f $_.Exception.Message) "ERROR"
}

Wait-MenuContinue
