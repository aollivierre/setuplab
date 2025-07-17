# Function to check if running as administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function for logging with color coding
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "INFO" { Write-Host $logMessage -ForegroundColor Green }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        default { Write-Host $logMessage -ForegroundColor White }
    }

    # Append to log file
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'install-VCppRedist.log')
    $logMessage | Out-File -FilePath $logFilePath -Append -Encoding utf8
}

# Function to add steps
function Add-Step {
    param (
        [string]$description
    )
    $global:steps.Add([PSCustomObject]@{ Description = $description })
}

# Function to log the current step
function Log-Step {
    $global:currentStep++
    $totalSteps = $global:steps.Count
    $stepDescription = $global:steps[$global:currentStep - 1].Description
    Write-Log "Step [$global:currentStep/$totalSteps]: $stepDescription" -Level "INFO"
}

# Function to download files with retry logic
function Start-BitsTransferWithRetry {
    param (
        [string]$Source,
        [string]$Destination,
        [int]$MaxRetries = 3
    )
    $attempt = 0
    $success = $false

    while ($attempt -lt $MaxRetries -and -not $success) {
        try {
            $attempt++
            if (-not (Test-Path -Path (Split-Path $Destination -Parent))) {
                throw "Destination path does not exist: $(Split-Path $Destination -Parent)"
            }
            $bitsTransferParams = @{
                Source      = $Source
                Destination = $Destination
                ErrorAction = "Stop"
            }
            Start-BitsTransfer @bitsTransferParams
            $success = $true
        }
        catch {
            Write-Log "Attempt $attempt failed: $_" -Level "ERROR"
            if ($attempt -eq $MaxRetries) {
                throw "Maximum retry attempts reached. Download failed."
            }
            Start-Sleep -Seconds 5
        }
    }
}

# Function to validate the installation of Visual C++ Redistributable
function Validate-VCppRedistInstallation {
    param (
        [Parameter(Mandatory=$true)]
        [string]$arch,
        
        [version]$MinVersion = [version]"14.40.33810.0",
        
        [int]$MaxRetries = 3,
        
        [int]$DelayBetweenRetries = 5
    )

    $retryCount = 0
    $validationSucceeded = $false
    $registryPath = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\$arch"
    $foundVersion = $null

    # Check standard path first
    if (Test-Path $registryPath) {
        $app = Get-ItemProperty -Path $registryPath
        # Remove the leading 'v' if present before parsing
        $installedVersionString = $app.Version -replace '^v', ''
        $installedVersion = [version]$installedVersionString
        $foundVersion = $installedVersion
        Write-Log "Found Visual C++ Redistributable ($arch) version $installedVersion." -Level "INFO"
        if ($installedVersion -ge $MinVersion) {
            Write-Log "Visual C++ Redistributable ($arch) version $installedVersion meets the minimum version requirement ($MinVersion)." -Level "INFO"
            return @{
                IsInstalled = $true
                Version     = $installedVersion
            }
        } else {
            Write-Log "Visual C++ Redistributable ($arch) version $installedVersion does not meet the minimum version requirement ($MinVersion)." -Level "WARNING"
            # No need to retry if the version is already found and not meeting the minimum
            return @{
                IsInstalled = $false
                Version     = $installedVersion
            }
        }
    } 
    # Check WOW6432Node path for x86 specifically
    elseif ($arch -eq "x86" -and (Test-Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\$arch")) {
        $app = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\$arch"
        # Remove the leading 'v' if present before parsing
        $installedVersionString = $app.Version -replace '^v', ''
        $installedVersion = [version]$installedVersionString
        $foundVersion = $installedVersion
        Write-Log "Found Visual C++ Redistributable ($arch) version $installedVersion." -Level "INFO"
        if ($installedVersion -ge $MinVersion) {
            Write-Log "Visual C++ Redistributable ($arch) version $installedVersion meets the minimum version requirement ($MinVersion)." -Level "INFO"
            return @{
                IsInstalled = $true
                Version     = $installedVersion
            }
        } else {
            Write-Log "Visual C++ Redistributable ($arch) version $installedVersion does not meet the minimum version requirement ($MinVersion)." -Level "WARNING"
            # No need to retry if the version is already found and not meeting the minimum
            return @{
                IsInstalled = $false
                Version     = $installedVersion
            }
        }
    } else {
        # If the path doesn't exist, no need to retry
        Write-Log "Visual C++ Redistributable ($arch) is not currently installed or does not meet the minimum version requirement." -Level "INFO"
        return @{
            IsInstalled = $false
        }
    }

    # ... (rest of the logic)
}

function Install-VCppRedist {
    param (
        [string]$arch
    )

    $global:steps = [System.Collections.Generic.List[PSCustomObject]]::new()
    $global:currentStep = 0
    $totalSteps = 5
    $completedSteps = 0
    $vcppUrl = "https://aka.ms/vs/17/release/vc_redist.$arch.exe"
    $vcppPath = "$env:TEMP\vc_redist_$arch.exe"
    $minVersion = [version]"14.40.33810.0"  # Adjust as necessary


    Test-Admin

    # Step 1: Pre-installation validation
    Add-Step "Validating existing installation of Visual C++ Redistributable ($arch)..."
    Log-Step
    
    $preValidationParams = @{
        arch                = $arch
        MinVersion          = $minVersion
        MaxRetries          = 3
        DelayBetweenRetries = 5
    }
    
    $preInstallCheck = Validate-VCppRedistInstallation @preValidationParams
    
    if ($preInstallCheck.IsInstalled) {
        Write-Log "Visual C++ Redistributable ($arch) version $($preInstallCheck.Version) is already installed. Skipping installation." -Level "INFO"
        return
    }
    else {
        Write-Log "Visual C++ Redistributable ($arch) is not currently installed or does not meet the minimum version requirement." -Level "INFO"
    }
    $completedSteps++

    # Step 2: Downloading Visual C++ Redistributable
    Add-Step "Downloading Visual C++ Redistributable ($arch)..."
    Log-Step
    
    try {
        if (-not (Test-Path -Path $env:TEMP)) {
            throw "The TEMP directory does not exist: $env:TEMP"
        }
        Start-BitsTransferWithRetry -Source $vcppUrl -Destination $vcppPath
        Write-Log "Download complete: The file has been downloaded to $vcppPath." -Level "INFO"
        $completedSteps++
    }
    catch {
        Write-Log "Error downloading Visual C++ Redistributable ($arch): $_" -Level "ERROR"
        exit 1
    }

    # Step 3: Installing Visual C++ Redistributable
    Add-Step "Installing Visual C++ Redistributable ($arch)..."
    Log-Step
    
    try {
        if (-not (Test-Path -Path $vcppPath)) {
            throw "The Visual C++ Redistributable installer file does not exist: $vcppPath"
        }
        $process = Start-Process -FilePath $vcppPath -ArgumentList "/install", "/quiet", "/norestart" -Wait -PassThru
        if ($process) {
            $process.WaitForExit()  # Ensure the process has fully completed
            Write-Log "Installation complete." -Level "INFO"
            $completedSteps++
        }
        else {
            throw "Failed to start the installation process."
        }
    }
    catch {
        Write-Log "Error installing Visual C++ Redistributable ($arch): $_" -Level "ERROR"
        exit 1
    }

    # Step 4: Post-installation validation
    Add-Step "Validating installation of Visual C++ Redistributable ($arch)..."
    Log-Step
    
    $postInstallCheck = Validate-VCppRedistInstallation @preValidationParams
    if ($postInstallCheck.IsInstalled) {
        Write-Log "Post-installation validation successful: Visual C++ Redistributable ($arch) version $($postInstallCheck.Version) is installed." -Level "INFO"
        $completedSteps++
    }
    else {
        Write-Log "Post-installation validation failed: Visual C++ Redistributable ($arch) was not found or does not meet the minimum version requirement." -Level "ERROR"
    }

    # Step 5: Cleaning up temporary files
    Add-Step "Cleaning up temporary files..."
    Log-Step
    
    try {
        if (Test-Path $vcppPath) {
            Remove-Item $vcppPath -Force
            Write-Log "Cleanup complete: Removed the installer file at $vcppPath." -Level "INFO"
            $completedSteps++
        }
    }
    catch {
        Write-Log "Error during cleanup: $_" -Level "ERROR"
        exit 1
    }

    # Summary report
    Write-Host "Summary: $completedSteps out of $totalSteps steps completed successfully." -ForegroundColor Cyan
    if ($completedSteps -eq $totalSteps) {
        Write-Host "Visual C++ Redistributable ($arch) was installed and validated successfully." -ForegroundColor Green
    }
    else {
        Write-Host "There were issues during the installation. Please check the log for details." -ForegroundColor Red
    }

    Read-Host 'Press Enter to close this window...'
}



# You can call the function as needed:
Install-VCppRedist -arch "x64"
Install-VCppRedist -arch "x86"