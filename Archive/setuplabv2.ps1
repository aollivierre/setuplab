# Directory for scripts
$scriptFolderPath = "$env:SystemDrive\InstallScripts"

If (!(Test-Path -Path $scriptFolderPath)) {
    New-Item -Path $scriptFolderPath -ItemType Directory -Force | Out-Null
}

# Function to create installation script
function Create-InstallScript {
    param (
        [string]$scriptName,
        [string]$content
    )
    $scriptPath = Join-Path -Path $scriptFolderPath -ChildPath $scriptName
    Out-File -FilePath $scriptPath -InputObject $content -Encoding ascii
    return $scriptPath
}

# Creating individual installation scripts
$vsCodeScript = @"
Write-Host 'Installing VS Code...'
\$installerPath = "`\$env:TEMP\VSCode.exe"
Invoke-WebRequest -Uri "https://update.code.visualstudio.com/latest/win32-x64/stable" -OutFile \$installerPath
Start-Process -FilePath \$installerPath -ArgumentList '/silent' -Wait
Write-Host 'VS Code installation complete.'
Read-Host 'Press Enter to close this window...'
"@
$vsCodeScriptPath = Create-InstallScript -scriptName "Install-VSCode.ps1" -content $vsCodeScript

$everythingScript = @"
Write-Host 'Installing Everything...'
\$installerPath = "`\$env:TEMP\Everything.exe"
Invoke-WebRequest -Uri "https://www.voidtools.com/Everything-1.4.1.1009.x64-Setup.exe" -OutFile \$installerPath
Start-Process -FilePath \$installerPath -ArgumentList '/S' -Wait
Write-Host 'Everything installation complete.'
Read-Host 'Press Enter to close this window...'
"@
$everythingScriptPath = Create-InstallScript -scriptName "Install-Everything.ps1" -content $everythingScript

$fileLocatorProScript = @"
Write-Host 'Installing File Locator Pro...'
\$installerPath = "`\$env:TEMP\FileLocatorPro.exe"
Invoke-WebRequest -Uri "https://download.mythicsoft.com/flp/3435/filelocator_3435.exe" -OutFile \$installerPath
Start-Process -FilePath \$installerPath -ArgumentList '/VERYSILENT' -Wait
Write-Host 'File Locator Pro installation complete.'
Read-Host 'Press Enter to close this window...'
"@
$fileLocatorProScriptPath = Create-InstallScript -scriptName "Install-FileLocatorPro.ps1" -content $fileLocatorProScript

$gitScript = @"
Write-Host 'Installing Git...'
\$installerPath = "`\$env:TEMP\Git.exe"
Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/latest/download/Git-2.41.0-64-bit.exe" -OutFile \$installerPath
Start-Process -FilePath \$installerPath -ArgumentList '/SILENT' -Wait
Write-Host 'Git installation complete.'
Read-Host 'Press Enter to close this window...'
"@
$gitScriptPath = Create-InstallScript -scriptName "Install-Git.ps1" -content $gitScript

$powerShell7Script = @"
Write-Host 'Installing PowerShell 7...'
\$installerPath = "`\$env:TEMP\PowerShell7.msi"
Invoke-WebRequest -Uri "https://github.com/PowerShell/PowerShell/releases/download/v7.3.5/PowerShell-7.3.5-win-x64.msi" -OutFile \$installerPath
Start-Process msiexec.exe -ArgumentList "/i \$installerPath /quiet /norestart" -Wait
Write-Host 'PowerShell 7 installation complete.'
Read-Host 'Press Enter to close this window...'
"@
$powerShell7ScriptPath = Create-InstallScript -scriptName "Install-PowerShell7.ps1" -content $powerShell7Script

$gitHubDesktopScript = @"
Write-Host 'Installing GitHub Desktop...'
\$installerPath = "`\$env:TEMP\GitHubDesktop.exe"
Invoke-WebRequest -Uri "https://desktop.githubusercontent.com/releases/3.1.4-12130e1e/GitHubDesktopSetup-x64.exe" -OutFile \$installerPath
Start-Process -FilePath \$installerPath -ArgumentList '/S' -Wait
Write-Host 'GitHub Desktop installation complete.'
Read-Host 'Press Enter to close this window...'
"@
$gitHubDesktopScriptPath = Create-InstallScript -scriptName "Install-GitHubDesktop.ps1" -content $gitHubDesktopScript

$windowsTerminalScript = @"
Write-Host 'Installing Windows Terminal...'
\$installerPath = "`\$env:TEMP\WindowsTerminal.msixbundle"
Invoke-WebRequest -Uri "https://github.com/microsoft/terminal/releases/latest/download/Microsoft.WindowsTerminal_1.13.11431.0_8wekyb3d8bbwe.msixbundle" -OutFile \$installerPath
Add-AppxPackage -Path \$installerPath
Write-Host 'Windows Terminal installation complete.'
# Create a shortcut on the desktop
\$desktopPath = [Environment]::GetFolderPath('Desktop')
\$shortcutPath = "`\$desktopPath\Windows Terminal.lnk"
\$shell = New-Object -ComObject WScript.Shell
\$shortcut = \$shell.CreateShortcut(\$shortcutPath)
\$shortcut.TargetPath = 'C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_1.13.11431.0_x64__8wekyb3d8bbwe\wt.exe'
\$shortcut.Save()
Write-Host 'Shortcut created on the desktop.'
Read-Host 'Press Enter to close this window...'
"@
$windowsTerminalScriptPath = Create-InstallScript -scriptName "Install-WindowsTerminal.ps1" -content $windowsTerminalScript

# Function to create scheduled task for a script
function Create-ScheduledTask {
    param (
        [string]$taskName,
        [string]$scriptPath,
        [int]$delaySeconds
    )
    $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <LogonTrigger>
      <Delay>PT${delaySeconds}S</Delay>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -ExecutionPolicy Bypass -NoExit -File $scriptPath</Arguments>
    </Exec>
  </Actions>
</Task>
"@
    $taskXmlPath = [System.IO.Path]::Combine($env:TEMP, "$taskName.xml")
    Out-File -FilePath $taskXmlPath -InputObject $taskXml -Encoding ascii
    schtasks.exe /create /tn "$taskName" /xml $taskXmlPath /f | Out-Null
    Remove-Item $taskXmlPath
}

# Create scheduled tasks for each script
Create-ScheduledTask -taskName "Install-VSCode" -scriptPath $vsCodeScriptPath -delaySeconds 5
Create-ScheduledTask -taskName "Install-Everything" -scriptPath $everythingScriptPath -delaySeconds 10
Create-ScheduledTask -taskName "Install-FileLocatorPro" -scriptPath $fileLocatorProScriptPath -delaySeconds 15
Create-ScheduledTask -taskName "Install-Git" -scriptPath $gitScriptPath -delaySeconds 20
Create-ScheduledTask -taskName "Install-PowerShell7" -scriptPath $powerShell7ScriptPath -delaySeconds 25
Create-ScheduledTask -taskName "Install-GitHubDesktop" -scriptPath $gitHubDesktopScriptPath -delaySeconds 30
Create-ScheduledTask -taskName "Install-WindowsTerminal" -scriptPath $windowsTerminalScriptPath -delaySeconds 35

# Function to enable RDP and add Everyone to the allowed list
function Enable-RDP {
    $script = @"
Write-Host 'Enabling RDP...'
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\' -Name 'fDenyTSConnections' -Value 0
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'
Write-Host 'RDP enabled.'

Write-Host 'Adding Everyone to the allowed RDP list...'
\$rdpGroup = [ADSI]'WinNT://./Remote Desktop Users,group'
\$everyone = [ADSI]'WinNT://./Everyone,user'
\$rdpGroup.Add(\$everyone.Path)
Write-Host 'Everyone added to the allowed RDP list.'
Read-Host 'Press Enter to close this window...'
"@
    $scriptPath = Create-InstallScript -scriptName "Enable-RDP.ps1" -content $script
    Create-ScheduledTask -taskName "Enable-RDP" -scriptPath $scriptPath -delaySeconds 40
}

# Enable RDP and add Everyone to the allowed list
Enable-RDP

# Output basic machine info
Output-MachineInfo

Write-Host "Setup complete. Please check the PowerShell windows for installation progress."
