function Install-GitFromWeb {
    param (
        [string]$url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-Git.ps1"
    )

    Write-EnhancedLog -Message "Attempting to install Git from URL: $url" -Level "INFO"

    $process = Invoke-WebScript -url $url
    if ($process) {
        $process.WaitForExit()

        # Perform post-installation validation
        $validationParams = @{
            SoftwareName        = "Git"
            MinVersion          = [version]"2.46.0"
            RegistryPath        = "HKLM:\SOFTWARE\GitForWindows"
            ExePath             = "C:\Program Files\Git\bin\git.exe"
            MaxRetries          = 3  # Single retry after installation
            DelayBetweenRetries = 5
        }

        $postValidationResult = Validate-SoftwareInstallation @validationParams
        if ($postValidationResult.IsInstalled -and $postValidationResult.Version -ge $validationParams.MinVersion) {
            Write-EnhancedLog -Message "Git successfully installed and validated." -Level "INFO"
            return $true
        }
        else {
            Write-EnhancedLog -Message "Git installation validation failed." -Level "ERROR"
            return $false
        }
    }
    else {
        Write-EnhancedLog -Message "Failed to start the installation process for Git." -Level "ERROR"
        return $false
    }
}