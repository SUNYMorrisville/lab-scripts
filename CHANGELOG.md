# Changelog

All notable changes to this repository are documented in this file.

## v2026.10.23.1 - 2026-10-23

### Fix — winget upgrade --all fails for per-user MSIX apps (Teams, WSL)

- `winget upgrade --all --scope machine` fails with `0x80070005` for per-user MSIX packages because winget tries to provision them for all users. Machine scope is kept (it prevents the sysprep failures fixed in 3d94263); when that pass reports failures, Lab Tools now offers an opt-in retry without machine scope, defaulting to No and warning to skip it on VM templates. Applies to Windows Client Tools > Utilities [4] / `U4` (new `Invoke-WingetUpgradeAll` in [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1)) and DevOps Install / Update [1] in [src/Menu/DevOpsInstallUpdateMenu.ps1](src/Menu/DevOpsInstallUpdateMenu.ps1).

### Fixes — launch, update, and menus

- [src/Launch-Elevated.vbs](src/Launch-Elevated.vbs): launch `%ProgramFiles%\PowerShell\7\pwsh.exe` by absolute path and fall back to Windows PowerShell. The desktop shortcut previously failed on machines without PowerShell 7, and the bare `pwsh.exe` name was resolved through the caller's PATH.
- Quote script paths passed to `Start-Process` in [src/Launch-LabTools.ps1](src/Launch-LabTools.ps1), [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1) (auto-update relaunch) and [src/Tasks/Update-LabTools.ps1](src/Tasks/Update-LabTools.ps1) (relaunch) so repo paths containing spaces work.
- [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1): a failed update from `U` no longer closes Lab Tools, and the update status refreshes afterwards. The update check skips `git fetch` when offline instead of freezing the menu. Global Search results for Sysprep, desktop wallpaper, and CITA 120 Lab 9 files now run (`VS`/`UW`/`UL` → `V5`/`U6`/`U7`).
- [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1): Sysprep stops if removing the Winget packages fails instead of launching Sysprep anyway; restarting Windows Update services and the VirtIO install now report failures. Consolidated the duplicated menu/search handlers into `Start-SysprepAfterWingetRemoval`, `Restart-WindowsUpdateServices`, and `Install-VirtIOGuestTools`. Fixed the elevated vmPing Public Desktop shortcut script, which was expanded too early and never parsed.
- [src/Menu/MaintenanceMenu.ps1](src/Menu/MaintenanceMenu.ps1): options 1 and 5 report failed tasks instead of always showing success.
- [src/UI/ConsoleUI.psm1](src/UI/ConsoleUI.psm1): uptime no longer rounds up to the next day; the TZ offset accounts for daylight saving time.

### Fixes — DevOps / Kubernetes lab

- [labs/k8s-baremetal-lab/bootstrap.ps1](labs/k8s-baremetal-lab/bootstrap.ps1): `Invoke-Talosctl` captures talosctl stderr on Windows PowerShell 5.1, so the x509/certificate guidance and the transient-error retries work. Answering N at the confirmation prompt exits with code 2 and the menu reports it as cancelled. Removing generated files keeps the tracked `student-overrides/README.md`.
- [src/Menu/DevOpsToolsMenu.ps1](src/Menu/DevOpsToolsMenu.ps1):
  - Automatic repo resets list the local changes and ask before discarding them (default No).
  - "Nuke local generated files" (`a2`) now targets `labs\k8s-baremetal-lab\...`, asks for confirmation, and keeps `README.md`.
  - kubectl probes no longer throw on 5.1 when a namespace is missing.
  - A missing kubeconfig shows the friendly message instead of a parameter-binding error.
  - `a7` returns to the submenu like `a1`–`a6`.
  - Worker IP input splits on commas correctly.
  - The dirty-repo hint points to the current reset option.
  - The Git auto-install uses `--exact`.
- [src/Menu/DevOpsQuickChecksMenu.ps1](src/Menu/DevOpsQuickChecksMenu.ps1): "Show installed versions" works on 5.1 and uses `talosctl version --client`.
- [labs/k8s-baremetal-lab/README.md](labs/k8s-baremetal-lab/README.md): parameter names and default IPs match `bootstrap.ps1`.

### Fixes — tasks

- [src/Tasks/Set-StaticIP.ps1](src/Tasks/Set-StaticIP.ps1):
  - IPv4 validation is strict. It rejects `192.168.1`, integer/hex forms, leading zeros, `0.0.0.0`, and `255.255.255.255`.
  - Prefix length must be 1–32, and the gateway must be a usable address in the subnet. Both are checked before any changes are made.
  - Re-applying the adapter's current address no longer fails the "in use" ping.
  - If applying fails, the adapter is reverted to DHCP instead of being left with no address.
- [src/Tasks/Rename-Computer.ps1](src/Tasks/Rename-Computer.ps1): allow-list validation (letters, digits, hyphens; not all digits; no leading/trailing hyphen).
- [src/Tasks/Run-SDelete.ps1](src/Tasks/Run-SDelete.ps1): accepts `C:\` (trailing backslash was never trimmed).
- [src/Tasks/Client/GPO-Report.ps1](src/Tasks/Client/GPO-Report.ps1): overwrites an existing report (`/f`) and reports gpresult failures.
- [src/Tasks/Apply-TerminalBackground.ps1](src/Tasks/Apply-TerminalBackground.ps1): if `settings.json` can't be parsed, warn and leave it alone instead of replacing it.
- Windows PowerShell 5.1 parse fixes: [src/Tasks/Client/Register-AutopilotDevice.ps1](src/Tasks/Client/Register-AutopilotDevice.ps1) (`?.`), [src/Tasks/Client/Set-DesktopWallpaper.ps1](src/Tasks/Client/Set-DesktopWallpaper.ps1) (non-ASCII dash in a string), [intune/winget/Setup-WingetUpgradeTask.ps1](intune/winget/Setup-WingetUpgradeTask.ps1) (`?.` in the generated script, so the nightly task never ran).
- [intune/winget/Setup-WingetUpgradeTask.ps1](intune/winget/Setup-WingetUpgradeTask.ps1): the task principal uses SID `S-1-5-32-545` instead of the English group name, and a failed registration no longer reports success.

### Version
- Bumped [src/VERSION.txt](src/VERSION.txt) to `v2026.10.23.1`.

## v2026.05.05.1 - 2026-05-05

### New Feature — Add Control Plane Node to Existing Cluster

- Added `Resolve-ControlPlaneConfigPath` function to [src/Menu/DevOpsToolsMenu.ps1](src/Menu/DevOpsToolsMenu.ps1): resolves `controlplane.yaml` from the same candidate paths used by `Resolve-WorkerConfigPath`.
- Added `"a7"` handler to [src/Menu/DevOpsToolsMenu.ps1](src/Menu/DevOpsToolsMenu.ps1): prompts for a control plane IP, validates reachability, and applies `controlplane.yaml` via `talosctl apply-config --insecure`. Follows the same flow as the existing worker add (`"a4"`).
- Added menu item `[7] Add new control plane node to existing cluster` to [src/Menu/DevOpsLabAdvancedOpsMenu.ps1](src/Menu/DevOpsLabAdvancedOpsMenu.ps1) and wired it to option map entry `"7" = "a7"`.
- Added `"a7"` entry to the global search catalog in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1) with keywords: `control plane node talos join cluster ha`.

### Version
- Bumped [src/VERSION.txt](src/VERSION.txt) to `v2026.05.05.1`.

## v2026.04.01.3 - 2026-04-01

### Refactor — Split Utilities into VM & Image Prep + Utilities

- Promoted SDelete, VM template prep, Horizon Optimization Tool, VirtIO tools, and Sysprep out of Utilities into a new top-level category **VM & Image Prep** (category 5) in [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1). These items share a cohesive VM build/golden-image workflow.
- **Utilities** (now category 6) is trimmed to 7 items: vmPing, Win11Debloat, winget shell, winget upgrade --all, new terminal tab, desktop wallpaper, and lab files.
- Added `Show-VMImagePrepMenu` and `Invoke-VMImagePrepMenu` functions with `V` prefix RunOptions (V1–V4, VS).
- Updated `Invoke-ClientRunOption` in [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1): added V-prefix cases; renumbered U3→winget shell, U4→winget upgrade, U5→new terminal tab (old U6–U8); removed stale U3–U5/U9/US entries.
- Updated global search catalog in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1): replaced old Utility entries with V-prefix VM & Image Prep entries; updated U3–U5 to match new numbering.

### Version
- Bumped [src/VERSION.txt](src/VERSION.txt) to `v2026.04.01.3`.

## v2026.04.01.2 - 2026-04-01

### New Feature — Copy CITA 120 Lab 9 Files to Public Desktop

- Added [labs/120/CITA120_L9_webpage.zip](labs/120/CITA120_L9_webpage.zip) lab asset folder.
- Added [src/Tasks/Client/Copy-CITA120L9Files.ps1](src/Tasks/Client/Copy-CITA120L9Files.ps1): copies `CITA120_L9_webpage.zip` from `labs/120/` to `C:\Users\Public\Desktop\`.
- Added **L** option to Windows Client Tools > Utilities in [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1): "Copy CITA 120 Lab 9 files to Public Desktop". Updated option count from 11 to 12 and the `Write-MenuKeysLine` hint.
- Added `UL` entry to the global search catalog in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1) with keywords: `cita 120 lab9 lab files copy desktop zip webpage`.

### Version
- Bumped [src/VERSION.txt](src/VERSION.txt) to `v2026.04.01.2`.

## v2026.04.01.1 - 2026-04-01

### New Feature — Apply CITA Desktop Wallpaper

- Added [src/Tasks/Client/Set-DesktopWallpaper.ps1](src/Tasks/Client/Set-DesktopWallpaper.ps1): copies `CITADesktopBackground.png` from the repo to `%APPDATA%\CITA\` (so the path is stable when the repo isn't mounted), disables Windows Spotlight on the desktop via `ContentDeliveryManager` registry keys, sets `BackgroundType = 0` (Picture) to override Spotlight, and applies the wallpaper live via Win32 `SystemParametersInfo`.
- Added **W** option to Windows Client Tools > Utilities in [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1): "Apply CITA desktop wallpaper (disables Spotlight)". Updated option count from 10 to 11 and the `Write-MenuKeysLine` hint.
- Added `UW` entry to the global search catalog in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1) with keywords: `wallpaper desktop background spotlight cita image apply`.

### Version
- Bumped [src/VERSION.txt](src/VERSION.txt) to `v2026.04.01.1`.

## v2026.03.20.1 - 2026-03-20

### UI / Navigation — Persistent Header

- Changed all sub-menu `Import-Module` calls for [src/UI/ConsoleUI.psm1](src/UI/ConsoleUI.psm1) from unconditional `-Force` to a conditional check (`if (-not (Get-Module ConsoleUI))`). This preserves the `$script:AppHeaderDrawn` module state across menu transitions so the in-place header overwrite works when navigating between menus. Affects: [ServerToolsMenu.ps1](src/Menu/ServerToolsMenu.ps1), [DCToolsMenu.ps1](src/Menu/DCToolsMenu.ps1), [MemberServerMenu.ps1](src/Menu/MemberServerMenu.ps1), [ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1), [TroubleshootingMenu.ps1](src/Menu/TroubleshootingMenu.ps1), [MaintenanceMenu.ps1](src/Menu/MaintenanceMenu.ps1), [DevOpsToolsMenu.ps1](src/Menu/DevOpsToolsMenu.ps1), [DevOpsInstallUpdateMenu.ps1](src/Menu/DevOpsInstallUpdateMenu.ps1), [DevOpsQuickChecksMenu.ps1](src/Menu/DevOpsQuickChecksMenu.ps1), [DevOpsLabInstallOpsMenu.ps1](src/Menu/DevOpsLabInstallOpsMenu.ps1), [DevOpsLabAdvancedOpsMenu.ps1](src/Menu/DevOpsLabAdvancedOpsMenu.ps1).
- Removed `Clear-Host` before `return` in all sub-menus. The exit clear was causing a blank-screen flicker when pressing `0` to go back to the main menu. [src/UI/ConsoleUI.psm1](src/UI/ConsoleUI.psm1) already clears below the header via `ESC[J` on each redraw, making the exit clear redundant.

### Version
- Bumped [src/VERSION.txt](src/VERSION.txt) to `v2026.03.20.1`.

## v2026.03.19.2 - 2026-03-19

### UI Color Enhancements

- Added `Write-MenuItem` and `Write-MenuKeysLine` shared helpers to [src/UI/ConsoleUI.psm1](src/UI/ConsoleUI.psm1) and exported them so all menus share a consistent colored rendering path.
- Updated [src/UI/ConsoleUI.psm1](src/UI/ConsoleUI.psm1) header box borders (`+---+` and `| |`) from DarkGray/Gray to Cyan, title line from Cyan to Yellow, and version value from Gray to Cyan.
- Updated `Write-BoxLine` in [src/UI/ConsoleUI.psm1](src/UI/ConsoleUI.psm1) to render border pipes (`| |`) in a separate `BorderColor` (default Cyan) from the text color.
- Applied `Write-MenuItem` (yellow keys, DarkGray brackets, colored label) and `Write-MenuKeysLine` (yellow keys, DarkGray text) across all menu files: [MainMenu.ps1](src/Menu/MainMenu.ps1), [DCToolsMenu.ps1](src/Menu/DCToolsMenu.ps1), [ServerToolsMenu.ps1](src/Menu/ServerToolsMenu.ps1), [MemberServerMenu.ps1](src/Menu/MemberServerMenu.ps1), [TroubleshootingMenu.ps1](src/Menu/TroubleshootingMenu.ps1), [MaintenanceMenu.ps1](src/Menu/MaintenanceMenu.ps1), [ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1), [DevOpsToolsMenu.ps1](src/Menu/DevOpsToolsMenu.ps1), [DevOpsInstallUpdateMenu.ps1](src/Menu/DevOpsInstallUpdateMenu.ps1), [DevOpsQuickChecksMenu.ps1](src/Menu/DevOpsQuickChecksMenu.ps1), [DevOpsLabInstallOpsMenu.ps1](src/Menu/DevOpsLabInstallOpsMenu.ps1), [DevOpsLabAdvancedOpsMenu.ps1](src/Menu/DevOpsLabAdvancedOpsMenu.ps1).
- Highlighted Maintenance option [1] (`Update Lab Tools from GitHub`) in Green in [src/Menu/MaintenanceMenu.ps1](src/Menu/MaintenanceMenu.ps1) to distinguish it as the primary update action.
- Simplified Maintenance option [1] label in [src/Menu/MaintenanceMenu.ps1](src/Menu/MaintenanceMenu.ps1) — shortcut repair and terminal background apply happen silently behind the scenes.

### Bug Fix

- Fixed null-reference error in [src/Menu/DevOpsToolsMenu.ps1](src/Menu/DevOpsToolsMenu.ps1) `Show-CurrentContext` where `Test-Path` was called with a `$null` kubeconfig path when no kubeconfig file exists; both call sites now guard with `$kubeconfigPath -and` before invoking `Test-Path`.

### Version
- Bumped [src/VERSION.txt](src/VERSION.txt) to `v2026.03.19.2`.

## v2026.03.19.1 - 2026-03-19

### Security and Code Quality Fixes

#### High Severity
- Updated [src/Tasks/Run-Win11Debloat.ps1](src/Tasks/Run-Win11Debloat.ps1) to download the upstream script to a temp file before execution rather than running it directly in-memory via `Invoke-RestMethod`, allowing OS/AV scanning and leaving an auditable path in output.
- Added a comment block to [src/Tasks/Create-Shortcuts.ps1](src/Tasks/Create-Shortcuts.ps1) documenting exactly what the `-EncodedCommand` elevation wrapper does, so future reviewers can verify it without decoding the base64.
- Added `Assert-ValidBranchName` in [src/Menu/DevOpsToolsMenu.ps1](src/Menu/DevOpsToolsMenu.ps1) to validate branch names before use in `git checkout` and `git reset --hard`, preventing potential argument injection if the variable origin changes.

#### Medium Severity
- Added `Assert-ValidIPv4` helper to [src/Tasks/Set-StaticIP.ps1](src/Tasks/Set-StaticIP.ps1) and applied it to IP address, gateway, and DNS inputs before any network cmdlets are called.
- Added reserved Windows device name check (`CON`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9`) to [src/Tasks/Rename-Computer.ps1](src/Tasks/Rename-Computer.ps1).
- Updated [src/Tasks/Set-EasternTimeAndResync.ps1](src/Tasks/Set-EasternTimeAndResync.ps1) to throw if the W32Time service is missing, use `-ErrorAction Stop` when starting it, and wait/verify the service reaches `Running` state before attempting resync.
- Fixed null reference in [src/Tasks/Client/Test-Connectivity.ps1](src/Tasks/Client/Test-Connectivity.ps1) where a nested `Get-CimInstance` call could throw if the parent process had already exited; split into two calls with null guards.
- Changed `Resolve-KubeconfigPath` fallback return value in [src/Menu/DevOpsToolsMenu.ps1](src/Menu/DevOpsToolsMenu.ps1) from `$candidates[0]` to `$null` so callers receive an unambiguous signal when no kubeconfig is found.

#### Low Severity
- Removed duplicate `Write-LabLog` definition (lines 1–13) from [src/Lib/Logging.psm1](src/Lib/Logging.psm1); the first definition was dead code with a hardcoded `C:\LabLogs\labtools.log` path.
- Added `$env:USERNAME` to the log line format in [src/Lib/Logging.psm1](src/Lib/Logging.psm1) for a complete audit trail.
- Added `Write-Verbose` to silent catch blocks in [src/UI/ConsoleUI.psm1](src/UI/ConsoleUI.psm1) (`Get-PrimaryNetworkInfo`, `Get-InternetStatus`, `Get-DomainMembershipInfo`, `Get-EntraJoinInfo`, `Get-CurrentJoinType`) so errors are surfaced when running with `-Verbose`.
- Switched kubectl interactive prompt in [src/Menu/DevOpsToolsMenu.ps1](src/Menu/DevOpsToolsMenu.ps1) from `-Command` with a dynamic string to `-EncodedCommand`; also fixed a pre-existing bug where `$env:KUBECONFIG` was expanded by the parent process instead of being assigned in the child.
- Added adapter re-verification step to [src/Tasks/Set-StaticIP.ps1](src/Tasks/Set-StaticIP.ps1) after the confirm prompt to catch the case where the selected adapter goes down before settings are applied.
- Added elevation comment to [src/Tasks/Client/Get-JoinStatus.ps1](src/Tasks/Client/Get-JoinStatus.ps1) documenting that admin rights are not required.

### Version
- Bumped [src/VERSION.txt](src/VERSION.txt) to `v2026.03.19.1`.

## v2026.03.12.1 - 2026-03-12

### Repository Consolidation
- Imported external repo history from `cronnpj/375` into [labs/375](labs/375) using a history-preserving subtree workflow.
- Imported external repo history from `cronnpj/320-assignment-5` into [labs/320/320-assignment-5](labs/320/320-assignment-5) using a history-preserving subtree workflow.
- Added [labs/320/README.md](labs/320/README.md) as a course-level index path for future 320 lab additions.
- Added [labs/375/README.md](labs/375/README.md) to describe imported 375 assets and configuration files.
- Updated [README.md](README.md) repository layout links to include consolidated lab paths.

## v2026.03.10.2 - 2026-03-10

### Maintenance and Shortcut Host Selection Updates
- Updated maintenance naming to `App Maintenance & Updates` in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1) and [src/Menu/MaintenanceMenu.ps1](src/Menu/MaintenanceMenu.ps1).
- Hardened shortcut host detection in [src/Tasks/Create-Shortcuts.ps1](src/Tasks/Create-Shortcuts.ps1) so `CITA Lab Tools.lnk` prefers PowerShell 7 when installed, using PATH checks, common install directories, and App Paths registry lookups before falling back to Windows PowerShell.
- Added selected-host logging in [src/Tasks/Create-Shortcuts.ps1](src/Tasks/Create-Shortcuts.ps1) to make shortcut host resolution visible during option [1]/[2] maintenance runs.

### Windows Client Utilities: Winget and Terminal Actions
- Expanded Windows Client Utilities in [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1) with options [6]-[8]: `Open winget command shell`, `Run winget upgrade --all`, and `Open new terminal tab`.
- Added Winget availability validation in [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1) with clear guidance when `winget.exe` is missing.
- Implemented `Open winget command shell` to launch a persistent shell tab/window and display a quick command cheat sheet for common Winget actions.
- Added global-search mappings (`RunOption = "U6"`, `"U7"`, `"U8"`) in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1) for the new Utilities actions.

## v2026.03.10.1 - 2026-03-10

### VM Template Prep Order Fix
- Updated [src/Tasks/Run-TemplatePrepChecklist.ps1](src/Tasks/Run-TemplatePrepChecklist.ps1) to present and execute the recommended template workflow in the correct order: run SDelete (`-z`) before Sysprep shutdown.
- Updated [src/MISC/SDelete/README.md](src/MISC/SDelete/README.md) to match the corrected VM template prep flow.

## v2026.03.09.1 - 2026-03-09

### Windows Client Utilities: SDelete Integration
- Added [src/Tasks/Run-HorizonOptimizationTool.ps1](src/Tasks/Run-HorizonOptimizationTool.ps1) to launch `VMwareHorizonOSOptimizationTool-x86_64.exe` in interactive mode.
- Updated [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1) Utilities to include option [5] `Launch VMware Horizon OS Optimization Tool`.
- Added direct global-search execution mapping in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1) (`RunOption = "U5"`) for the Horizon Optimization Tool.
- Added MISC placement docs in [src/MISC/README.md](src/MISC/README.md) and [src/MISC/VMwareHorizonOSOptimizationTool/README.md](src/MISC/VMwareHorizonOSOptimizationTool/README.md).
- Simplified [src/Tasks/Update-LabTools.ps1](src/Tasks/Update-LabTools.ps1) to in-place runtime-repo updates only; removed repo-cache/deploy behavior that created `C:\CITA\_LabToolsRepo`, `C:\CITA\LabTools`, and backup folders.
- Updated repo detection in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1) to use runtime root git repo only for update status checks.
- Updated vmPing launch flow in [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1) so Utilities option [1] now ensures `vmPing.lnk` exists on both current-user Desktop and Public Desktop before launching.
- Added skip-if-exists behavior for vmPing shortcut creation and non-blocking handling when Public Desktop shortcut creation is not permitted.
- Added Maintenance option [6] in [src/Menu/MaintenanceMenu.ps1](src/Menu/MaintenanceMenu.ps1) for `Install / Repair PS7 only`.
- Added [src/Tasks/Install-PowerShell7Only.ps1](src/Tasks/Install-PowerShell7Only.ps1) for dedicated PowerShell 7 install/repair without Graph module/sign-in steps.
- Added [src/Tasks/Run-TemplatePrepChecklist.ps1](src/Tasks/Run-TemplatePrepChecklist.ps1) for guided Proxmox VM template prep (Sysprep prompt + optional SDelete handoff + post-step reminders).
- Updated [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1) Utilities to include option [4] `Run VM template prep checklist`.
- Added direct global-search execution mapping in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1) (`RunOption = "U4"`) for the template prep checklist.
- Added [src/Tasks/Run-SDelete.ps1](src/Tasks/Run-SDelete.ps1) to run Sysinternals SDelete interactively with:
	- default `-z` mode (zero free space, VM-template friendly)
	- optional `-c` mode
	- drive selection prompt (defaults to `C:`)
	- admin/elevation and executable presence checks
- Updated [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1) Utilities from 2 to 3 options and added `Run SDelete free-space overwrite` as option [3].
- Added direct global-search execution mapping in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1) (`RunOption = "U3"`) for SDelete.
- Added deployable MISC docs for SDelete placement in:
	- [src/MISC/README.md](src/MISC/README.md)
	- [src/MISC/SDelete/README.md](src/MISC/SDelete/README.md)

## v2026.03.05.1 - 2026-03-05

### Header Layout and Status Enhancements
- Added domain membership detection in [src/UI/ConsoleUI.psm1](src/UI/ConsoleUI.psm1) with `Domain`, `Workgroup`, and `None` states shown in the app header.
- Combined `Internet` and `Domain` status into one row in [src/UI/ConsoleUI.psm1](src/UI/ConsoleUI.psm1) to reduce header height.
- Updated header row alignment logic in [src/UI/ConsoleUI.psm1](src/UI/ConsoleUI.psm1) so right-side labels (`User`, `Mode`, `Domain`, `Date`) align to a consistent column.
- Tuned spacing offsets in [src/UI/ConsoleUI.psm1](src/UI/ConsoleUI.psm1) for `Mode`, `Domain`, and `Date` to match the current dashboard layout.

### Shortcut Behavior Updates
- Updated [src/config/labtools.json](src/config/labtools.json) default `shortcuts.createPublicDesktopShortcuts` to `true` so public desktop shortcut creation is enabled by default.
- Updated [src/Tasks/Create-Shortcuts.ps1](src/Tasks/Create-Shortcuts.ps1) to self-elevate when needed for all-users shortcut locations.
- Updated [src/Tasks/Create-Shortcuts.ps1](src/Tasks/Create-Shortcuts.ps1) shortcut launch arguments to run Lab Tools elevated (`Start-Process -Verb RunAs`).

## v2026.03.04.2 - 2026-03-04

### Client Utilities Menu Reorganization
- Moved `Run Win11Debloat (official upstream script)` from [src/Menu/MaintenanceMenu.ps1](src/Menu/MaintenanceMenu.ps1) to Windows Client Tools > Utilities in [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1).
- Expanded Utilities in [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1) from 1 option to 2 options so `vmPing` and `Win11Debloat` are grouped together.
- Updated Maintenance option/key hints in [src/Menu/MaintenanceMenu.ps1](src/Menu/MaintenanceMenu.ps1) to reflect options [1]-[4] only.

### Global Search Catalog Update
- Added a direct search action for `Run Win11Debloat` (`RunOption = "U2"`) under Windows Client Tools > Utilities in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1).
- Kept Maintenance search coverage in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1) focused on update/shortcut/background/feedback tasks.

## v2026.03.04.1 - 2026-03-04

### Header Status and Client Menu Guidance
- Added an `Internet` status indicator in [src/UI/ConsoleUI.psm1](src/UI/ConsoleUI.psm1) to the app header with green/red checkmark state.
- Updated [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1) top-level Windows Client categories with short context descriptions and option counts to improve discoverability.
- Styled Windows Client category description lines with `DarkGray` in [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1) for better visual hierarchy.

### Global Search and Direct Action Execution
- Added a single global search entry on the main menu in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1) (`[S] Global Search`) with keyword matching across major tool areas.
- Expanded global search catalog coverage to include granular Windows Client, Troubleshooting, and DevOps actions in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1).
- Fixed single-result rendering in global search by normalizing match results as an array in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1).
- Added direct action execution from search results (instead of only opening menus) by introducing `RunOption` pathways in:
	- [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1)
	- [src/Menu/TroubleshootingMenu.ps1](src/Menu/TroubleshootingMenu.ps1)
	- [src/Menu/DevOpsInstallUpdateMenu.ps1](src/Menu/DevOpsInstallUpdateMenu.ps1)
	- [src/Menu/DevOpsQuickChecksMenu.ps1](src/Menu/DevOpsQuickChecksMenu.ps1)
- Added a pre-execution confirmation line (`Running: <Area> > <Item>`) in [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1) before launching a search-selected action.

## v2026.03.03.2 - 2026-03-03

### Maintenance Menu Addition
- Added a Win11Debloat pathway in [src/Menu/MaintenanceMenu.ps1](src/Menu/MaintenanceMenu.ps1) as option [5] (`Run Win11Debloat (official upstream script)`).
- Added [src/Tasks/Run-Win11Debloat.ps1](src/Tasks/Run-Win11Debloat.ps1), which opens the upstream project page on request and runs the official command from `https://debloat.raphi.re/` only after explicit user confirmation.

## v2026.03.03.1 - 2026-03-03

### Feedback and Menu UX Updates
- Added a feedback/reporting pathway using Microsoft Forms (`https://forms.office.com/r/5pJZNxzxgq`) in [src/Menu/MaintenanceMenu.ps1](src/Menu/MaintenanceMenu.ps1) as option [4] (`Report a Problem / Submit Feedback`).
- Removed the feedback option from [src/Menu/MainMenu.ps1](src/Menu/MainMenu.ps1) to keep the main menu uncluttered.
- Updated Maintenance menu key hints in [src/Menu/MaintenanceMenu.ps1](src/Menu/MaintenanceMenu.ps1) to reflect options [1]-[4].

### Maintenance Task Flow and Pause Behavior
- Updated option [1] in [src/Menu/MaintenanceMenu.ps1](src/Menu/MaintenanceMenu.ps1) to run update + shortcut repair + terminal background in sequence with a single menu pause at the end.
- Added optional pause control (`ShowPause`) in maintenance/client menu task helpers to reduce duplicate continue prompts during chained actions.
- Adjusted connectivity-task prompt handling in [src/Tasks/Client/Test-Connectivity.ps1](src/Tasks/Client/Test-Connectivity.ps1) to better avoid duplicate `Press Enter to continue` prompts when launched from menu flows.

## v2026.02.25.2 - 2026-02-25

### Maintenance Update Flow Fix
- Updated [src/Tasks/Update-LabTools.ps1](src/Tasks/Update-LabTools.ps1) post-update task discovery to support both deployed-root (`...\Tasks`) and repo-root (`...\src\Tasks`) layouts.
- This resolves option [1] cases where repo pull succeeded but shortcut/background steps were incorrectly skipped as "task not found".

## v2026.02.25.1 - 2026-02-25

### Maintenance Update Flow Fix
- Updated [src/Tasks/Update-LabTools.ps1](src/Tasks/Update-LabTools.ps1) to resolve post-update task scripts from the updater's local task folder first, with fallback to deployed `C:\CITA\LabTools\Tasks` paths.
- Added explicit post-update script-path logging so option [1] output shows exactly which shortcut/background task script is executed.

## v2026.02.25 - 2026-02-25

### Maintenance Update Flow
- Updated [src/Tasks/Update-LabTools.ps1](src/Tasks/Update-LabTools.ps1) so Maintenance option [1] now includes post-update shortcut repair by running `Create-Shortcuts.ps1` (non-blocking on failure).
- Kept post-update Windows Terminal background apply behavior in [src/Tasks/Update-LabTools.ps1](src/Tasks/Update-LabTools.ps1), so option [1] now covers both prior options [2] and [3] checks/actions.
- Updated Maintenance menu text in [src/Menu/MaintenanceMenu.ps1](src/Menu/MaintenanceMenu.ps1) to reflect that option [1] includes shortcut repair and terminal background apply.

## v2026.02.23.1 - 2026-02-23

### Shortcut and UX Refinements
- Updated [src/Tasks/Create-Shortcuts.ps1](src/Tasks/Create-Shortcuts.ps1) to create only `CITA Lab Tools.lnk`.
- Added legacy cleanup behavior to remove `CITA Server Setup.lnk` from managed shortcut locations when present.
- Added shortcut icon configuration in [src/config/labtools.json](src/config/labtools.json) via `shortcuts.iconRelativePath`, with fallback to the default PowerShell icon.
- Added [src/MISC/Icons/README.md](src/MISC/Icons/README.md) and a default icon folder for custom shortcut icon placement.
- Reduced noisy expected warnings by skipping all-users Desktop/Start Menu writes and public desktop cleanup when not running elevated.
- Kept public desktop shortcut behavior configurable via `shortcuts.createPublicDesktopShortcuts` (default `false`).

## v2026.02.22 - 2026-02-22

### Menu and Launch Experience
- Added [src/Launch-LabTools.ps1](src/Launch-LabTools.ps1) to start Lab Tools in Windows Terminal (`wt.exe`) when available, with PowerShell fallback.
- Added Windows Client Tools option [16] in [src/Menu/ClientToolsMenu.ps1](src/Menu/ClientToolsMenu.ps1) to launch vmPing from the local MISC path.
- Added [src/Tasks/Create-Shortcuts.ps1](src/Tasks/Create-Shortcuts.ps1) and Maintenance option [2] to create/repair current-user Desktop and Start Menu shortcuts.
- Expanded [src/Tasks/Create-Shortcuts.ps1](src/Tasks/Create-Shortcuts.ps1) to also repair legacy shortcut name (`CITA Server Setup.lnk`) and attempt all-users Desktop/Start Menu locations.
- Added [src/Tasks/Apply-TerminalBackground.ps1](src/Tasks/Apply-TerminalBackground.ps1) and Maintenance option [3] to apply Windows Terminal background settings from [src/config/terminal-background.json](src/config/terminal-background.json).
- Updated [src/Tasks/Update-LabTools.ps1](src/Tasks/Update-LabTools.ps1) to auto-run the Terminal background apply step after successful updates (non-blocking if it fails).

### MISC Asset Structure
- Added [src/MISC/README.md](src/MISC/README.md) as a deployable location for executables, images, and other growth assets.
- Added [src/MISC/vmPing/README.md](src/MISC/vmPing/README.md) with vmPing placement guidance (`vmPing.exe`).

## v2026.02.20 - 2026-02-20

### DevOps Menu Hardening
- Strengthened repo prerequisite flow with pre/post repair checks and safer sync conditions.
- Switched dirty-repo reset controls to explicit boolean behavior with conservative defaults.
- Added explicit git fetch/checkout/pull exit-code validation for clearer failure handling.
- Tightened readiness checks for valid git repo state and reachable kubeconfig where required.
- Improved menu UX with corrected option ordering, reduced redundant pauses, and clearer error/remediation messaging.
- Updated option [9] to prompt for control-plane and worker IPs while keeping adaptive full-build/add-ons workflow.
- Removed option [16] and renumbered Advanced Operations menu entries to maintain contiguous numbering.
- Expanded option [11] Portainer publishing to support Ingress host mode, NodePort IP mode, and LoadBalancer VIP mode.

### Documentation and Versioning
- Added a README recent-updates section for v2026.02.20.
- Bumped repository version to v2026.02.20.
