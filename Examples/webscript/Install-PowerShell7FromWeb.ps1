
function Install-PowerShell7FromWeb {
    param (
        [string]$url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-PowerShell7.ps1"
    )

    Write-EnhancedLog -Message "Attempting to install PowerShell 7 from URL: $url" -Level "INFO"

    $process = Invoke-WebScript -url $url
    if ($process) {
        $process.WaitForExit()

        # Perform post-installation validation
        $validationParams = @{
            SoftwareName        = "PowerShell"
            MinVersion          = [version]"7.4.4"
            RegistryPath        = "HKLM:\SOFTWARE\Microsoft\PowerShellCore"
            ExePath             = "C:\Program Files\PowerShell\7\pwsh.exe"
            MaxRetries          = 3  # Single retry after installation
            DelayBetweenRetries = 5
        }

        $postValidationResult = Validate-SoftwareInstallation @validationParams
        if ($postValidationResult.IsInstalled -and $postValidationResult.Version -ge $validationParams.MinVersion) {
            Write-EnhancedLog -Message "PowerShell 7 successfully installed and validated." -Level "INFO"
            return $true
        }
        else {
            Write-EnhancedLog -Message "PowerShell 7 installation validation failed." -Level "ERROR"
            return $false
        }
    }
    else {
        Write-EnhancedLog -Message "Failed to start the installation process for PowerShell 7." -Level "ERROR"
        return $false
    }
}