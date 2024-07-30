# Install-GitHubDesktop.ps1
function Install-GitHubDesktop {
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'GitHubDesktop.exe')
    Write-Host 'Downloading GitHub Desktop...'
    Invoke-WebRequest -Uri 'https://desktop.githubusercontent.com/github-desktop/releases/3.4.2-27793d93/GitHubDesktopSetup-x64.exe' -OutFile $installerPath | Out-Null
    Write-Host 'Download complete.'

    Write-Host "Installer path: $installerPath"

    Write-Host 'Installing GitHub Desktop...'
    Start-Process -FilePath $installerPath -ArgumentList '/S' -Wait
    Write-Host 'Installation complete.'
    Read-Host 'Press Enter to close this window...'
}

# Call the Install-GitHubDesktop function
Install-GitHubDesktop
