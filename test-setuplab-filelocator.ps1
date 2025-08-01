# Test SetupLab with FileLocator Pro MSI installation

# Import the SetupLab module
Import-Module "C:\code\setuplab\SetupLabCore.psm1" -Force

Write-Host "=== Testing FileLocator Pro through SetupLab ===" -ForegroundColor Cyan

# Create a minimal test config
$testConfig = @{
    configurations = @{
        skipValidation = $false
        maxConcurrency = 1
        logLevel = "Debug"
    }
    software = @(
        @{
            name = "FileLocator Pro"
            enabled = $true
            registryName = "FileLocator Pro"
            executablePath = "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
            downloadUrl = "https://download.mythicsoft.com/flp/3522/filelocator_x64_msi_3522.zip"
            installerExtension = ".zip"
            installType = "MSI_ZIP"
            installArguments = @("/quiet", "/norestart")
            minimumVersion = $null
            category = "Utilities"
        }
    )
}

# Save test config
$testConfigPath = Join-Path $env:TEMP "test-filelocator-config.json"
$testConfig | ConvertTo-Json -Depth 10 | Set-Content $testConfigPath

Write-Host "Test config saved to: $testConfigPath" -ForegroundColor Gray

# Test the installation
try {
    # First check if already installed
    $installed = Test-SoftwareInstalled -Name "FileLocator Pro" -ExecutablePath "C:\Program Files\Mythicsoft\FileLocator Pro\FileLocatorPro.exe"
    
    if ($installed) {
        Write-Host "FileLocator Pro is already installed - uninstall it first to test" -ForegroundColor Yellow
        
        # Try to find uninstaller
        $uninstallKey = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
                       Where-Object { $_.DisplayName -like "*FileLocator*" } | 
                       Select-Object -First 1
        
        if ($uninstallKey -and $uninstallKey.UninstallString) {
            Write-Host "Uninstall command: $($uninstallKey.UninstallString)" -ForegroundColor Gray
        }
    } else {
        Write-Host "FileLocator Pro not installed - proceeding with test" -ForegroundColor Green
        
        # Load the config
        $config = Get-SoftwareConfiguration -ConfigFile $testConfigPath
        
        # Get FileLocator Pro from config
        $fileLocator = $config.software | Where-Object { $_.name -eq "FileLocator Pro" }
        
        if ($fileLocator) {
            Write-Host ""
            Write-Host "Testing installation..." -ForegroundColor Yellow
            Write-Host "*** WATCH FOR ANY UI DIALOGS ***" -ForegroundColor Red
            Write-Host ""
            
            # Download the installer
            $downloadPath = Join-Path $env:TEMP "filelocator_msi.zip"
            Start-SetupDownload -Url $fileLocator.downloadUrl -Destination $downloadPath
            
            # Install using our new MSI_ZIP type
            Invoke-SetupInstaller -InstallerPath $downloadPath -InstallType "MSI_ZIP" -Arguments $fileLocator.installArguments
            
            # Validate installation
            $installed = Test-SoftwareInstalled -Name "FileLocator Pro" -ExecutablePath $fileLocator.executablePath
            
            if ($installed) {
                Write-Host ""
                Write-Host "SUCCESS: FileLocator Pro installed through SetupLab!" -ForegroundColor Green
                Write-Host "*** WAS THE INSTALLATION COMPLETELY SILENT? ***" -ForegroundColor Red
            } else {
                Write-Host "FAILED: Installation validation failed" -ForegroundColor Red
            }
        }
    }
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

# Cleanup
if (Test-Path $testConfigPath) {
    Remove-Item $testConfigPath -Force
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan