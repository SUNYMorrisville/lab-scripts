Dim sh, fso, wsh, scriptDir, launcher, args, psExe
Set sh  = CreateObject("Shell.Application")
Set fso = CreateObject("Scripting.FileSystemObject")
Set wsh = CreateObject("WScript.Shell")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
launcher  = scriptDir & "\Launch-LabTools.ps1"
args      = "-NoLogo -ExecutionPolicy Bypass -File """ & launcher & """"

' Absolute paths only: a bare "pwsh.exe" is resolved through the caller's PATH,
' and machines without PowerShell 7 need to fall back to Windows PowerShell.
psExe = wsh.ExpandEnvironmentStrings("%ProgramFiles%") & "\PowerShell\7\pwsh.exe"
If Not fso.FileExists(psExe) Then
    psExe = wsh.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
End If
sh.ShellExecute psExe, args, scriptDir, "runas", 0
