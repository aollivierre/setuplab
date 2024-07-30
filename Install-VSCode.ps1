# Install-VSCode.ps1
function Install-VSCode {
    $installerPath = [System.IO.Path]::Combine($env:TEMP, 'VSCode.exe')
    Write-Host 'Downloading VS Code...'
    Invoke-WebRequest -Uri 'https://update.code.visualstudio.com/latest/win32-x64/stable' -OutFile $installerPath | Out-Null
    Write-Host 'Download complete.'

    Write-Host "Installer path: $installerPath"

    Write-Host 'Installing VS Code...'
    Start-Process -FilePath $installerPath -ArgumentList '/silent /mergetasks=!runcode' -Wait
    Write-Host 'Installation complete.'
}

# Call the Install-VSCode function
Install-VSCode