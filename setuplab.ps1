# Call-Install-Software.ps1
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$scriptRoot\Install-VSCode.ps1`""
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$scriptRoot\Install-Everything.ps1`""

# still need to make it more silent than now
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$scriptRoot\Install-FileLocatorPro.ps1`"" 

Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$scriptRoot\Install-Git.ps1`""
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$scriptRoot\Install-PowerShell7.ps1`""
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$scriptRoot\Install-GitHubDesktop.ps1`""
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$scriptRoot\Install-WindowsTerminal.ps1`""