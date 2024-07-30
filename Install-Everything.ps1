# Install-Everything.ps1
function Install-Everything {
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'Everything.exe')
    Write-Host 'Downloading Everything...'
    Invoke-WebRequest -Uri 'https://www.voidtools.com/Everything-1.4.1.1024.x64-Setup.exe' -OutFile $installerPath | Out-Null
    Write-Host 'Download complete.'

    Write-Host "Installer path: $installerPath"

    Write-Host 'Installing Everything...'
    Start-Process -FilePath $installerPath -ArgumentList '/S' -Wait
    Write-Host 'Installation complete.'
    Read-Host 'Press Enter to close this window...'
}

# Call the Install-Everything function
Install-Everything
