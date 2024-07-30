# Install-FileLocatorPro.ps1
function Install-FileLocatorPro {
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'FileLocatorPro.exe')
    Write-Host 'Downloading File Locator Pro...'
    Invoke-WebRequest -Uri 'https://download.mythicsoft.com/flp/3435/filelocator_3435.exe' -OutFile $installerPath | Out-Null
    Write-Host 'Download complete.'

    Write-Host "Installer path: $installerPath"

    Write-Host 'Installing File Locator Pro...'
    Start-Process -FilePath $installerPath -ArgumentList '/VERYSILENT' -Wait
    Write-Host 'Installation complete.'
    Read-Host 'Press Enter to close this window...'
}

# Call the Install-FileLocatorPro function
Install-FileLocatorPro