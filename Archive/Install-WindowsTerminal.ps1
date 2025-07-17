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
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'install-windowsterminal.log')
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


# Function to validate Windows Terminal installation via the existence of the executable and version check
function Validate-WindowsTerminalInstallation {
    param (
        [string]$ExePath,
        [version]$MinVersion,
        [int]$MaxRetries = 3,
        [int]$DelayBetweenRetries = 5
    )
    
    $retryCount = 0
    $validationSucceeded = $false

    while ($retryCount -lt $MaxRetries -and -not $validationSucceeded) {
        if (Test-Path $ExePath) {
            $appFolder = Split-Path -Path $ExePath -Parent
            $appVersion = [version]($appFolder -replace '.+\\Microsoft\.WindowsTerminal_(.*?)_8wekyb3d8bbwe', '$1')

            if ($appVersion -ge $MinVersion) {
                return @{
                    IsInstalled = $true
                    Version     = $appVersion
                    Path        = $ExePath
                }
            }
        }
        
        $retryCount++
        Write-Log "Validation attempt $retryCount failed: Windows Terminal not found or version does not meet the minimum requirement ($MinVersion). Retrying in $DelayBetweenRetries seconds..." -Level "WARNING"
        Start-Sleep -Seconds $DelayBetweenRetries
    }

    return @{IsInstalled = $false }
}



# Function to get the latest Windows Terminal download URL
function Get-LatestWindowsTerminalUrl {
    try {
        Write-Log "Fetching the latest Windows Terminal release info..." -Level "INFO"
        $restMethodParams = @{
            Uri     = 'https://api.github.com/repos/microsoft/terminal/releases/latest'
            Headers = @{ 'User-Agent' = 'PowerShell' }
        }
        $latestRelease = Invoke-RestMethod @restMethodParams
        $url = $latestRelease.assets | Where-Object { $_.name -like '*x64.zip' } | Select-Object -ExpandProperty browser_download_url
        Write-Log "Latest Windows Terminal ZIP URL found: $url" -Level "INFO"
        return $url
    }
    catch {
        Write-Log "Error fetching the latest Windows Terminal release info: $_" -Level "ERROR"
        exit 1
    }
}

# Main installation function
function Install-WindowsTerminal {
    $global:steps = [System.Collections.Generic.List[PSCustomObject]]::new()
    $global:currentStep = 0
    $totalSteps = 7
    $completedSteps = 0

    Add-Step "Validating existing installation of Windows Terminal"
    Add-Step "Fetching the latest Windows Terminal release info"
    Add-Step "Downloading Windows Terminal"
    Add-Step "Extracting Windows Terminal"
    Add-Step "Creating shortcut for Windows Terminal"
    Add-Step "Post-installation validation"
    Add-Step "Cleaning up temporary files"

    # Step 1: Pre-installation validation
    Log-Step

    # Check for the existing installation at the final installation path
    $exePath = "C:\Program Files\WindowsTerminal\WindowsTerminal.exe"

    # Check if the executable exists at the predefined installation path
    if (Test-Path $exePath) {
        $appVersionString = (Get-ItemProperty -Path $exePath).VersionInfo.ProductVersion
        $appVersion = [version]$appVersionString

        # Define the minimum required version
        $minVersion = [version]"1.20.240626001"

        if ($appVersion -ge $minVersion) {
            Write-Log "Windows Terminal version $appVersion is already installed at $exePath and meets the minimum version requirement. Skipping installation." -Level "INFO"
            return
        }
        else {
            Write-Log "Windows Terminal version $appVersion does not meet the minimum version requirement ($minVersion). Proceeding with installation." -Level "INFO"
        }
    }
    else {
        Write-Log "Windows Terminal is not currently installed." -Level "INFO"
    }

    $completedSteps++






    # Step 2: Fetching the latest Windows Terminal release info
    Log-Step
    $url = Get-LatestWindowsTerminalUrl
    $completedSteps++

    # Step 3: Downloading Windows Terminal
    Log-Step
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $zipPath = [System.IO.Path]::Combine($env:TEMP, "WindowsTerminal_$timestamp.zip")
    try {
        Start-BitsTransferWithRetry -Source $url -Destination $zipPath
        Write-Log "Download complete: The Windows Terminal ZIP file has been downloaded to $zipPath." -Level "INFO"
    }
    catch {
        Write-Log "Error downloading Windows Terminal: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++


    # Step 4: Extracting Windows Terminal
    Log-Step
    $permanentPath = "$env:ProgramFiles\WindowsTerminal"  # Define a more permanent installation directory
    $extractPath = [System.IO.Path]::Combine($env:TEMP, "WindowsTerminal_$timestamp")
    try {
        if (Test-Path $extractPath) {
            Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed existing directory at $extractPath before extraction." -Level "INFO"
        }
        New-Item -Path $extractPath -ItemType Directory | Out-Null
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        Write-Log "Extraction complete: The Windows Terminal files have been extracted to $extractPath." -Level "INFO"

        # Move the extracted files to the permanent location
        if (Test-Path $permanentPath) {
            Remove-Item -Path $permanentPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed existing directory at $permanentPath to avoid conflicts." -Level "INFO"
        }
        Move-Item -Path $extractPath\* -Destination $permanentPath
        Write-Log "Files moved to $permanentPath for permanent storage." -Level "INFO"
    }
    catch {
        Write-Log "Error extracting or moving Windows Terminal files: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++


    # Step 5: Creating shortcut for Windows Terminal
    Log-Step
    try {
        $exePath = Get-ChildItem -Path $permanentPath -Filter "WindowsTerminal.exe" -Recurse | Select-Object -First 1 -ExpandProperty FullName
        Write-Log "Executable found at $exePath." -Level "INFO"
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $shortcutPath = [System.IO.Path]::Combine($desktopPath, 'Windows Terminal.lnk')
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $exePath
        $shortcut.Save()
        Write-Log 'Shortcut created on the desktop at $shortcutPath.' -Level "INFO"
    }
    catch {
        Write-Log "Error creating shortcut: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++



    # Step 6: Post-installation validation
    Log-Step

    # Use the newly installed path for validation
    $exePath = "C:\Program Files\WindowsTerminal\WindowsTerminal.exe"

    # Check if the executable exists at the new path
    if (Test-Path $exePath) {
        $appVersionString = (Get-ItemProperty -Path $exePath).VersionInfo.ProductVersion
        $appVersion = [version]$appVersionString

        # Define the minimum required version
        $minVersion = [version]"1.20.240626001"

        if ($appVersion -ge $minVersion) {
            Write-Log "Post-installation validation successful: Windows Terminal version $appVersion is installed at $exePath." -Level "INFO"
            $completedSteps++
        }
        else {
            Write-Log "Post-installation validation failed: Windows Terminal version $appVersion does not meet the minimum version requirement ($minVersion)." -Level "ERROR"
        }
    }
    else {
        Write-Log "Post-installation validation failed: Windows Terminal was not found on the system." -Level "ERROR"
    }


  

    # Step 7: Cleaning up temporary files
    Log-Step
    try {
        Remove-Item -Path $zipPath -Recurse -Force
        Write-Log "Cleanup complete: Removed the downloaded ZIP file at $zipPath." -Level "INFO"
        # Note: No need to clean up the extracted path since files were moved to permanentPath
    }
    catch {
        Write-Log "Error during cleanup: $_" -Level "ERROR"
        exit 1
    }
    $completedSteps++



    # Summary report
    Write-Host "Summary: $completedSteps out of $totalSteps steps completed successfully." -ForegroundColor Cyan
    if ($completedSteps -eq $totalSteps) {
        Write-Host "Windows Terminal was installed and validated successfully." -ForegroundColor Green
    }
    else {
        Write-Host "There were issues during the installation. Please check the log for details." -ForegroundColor Red
    }

    # Keep the PowerShell window open to review the logs
    Read-Host 'Press Enter to close this window...'
}

# Elevate to administrator if not already
if (-not (Test-Admin)) {
    Write-Log "Restarting script with elevated permissions..."
    $startProcessParams = @{
        FilePath     = "powershell.exe"
        ArgumentList = @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath)
        Verb         = "RunAs"
    }
    Start-Process @startProcessParams
    exit
}

# Call the Install-WindowsTerminal function
Install-WindowsTerminal