# Initialize the global steps list
$global:steps = [System.Collections.Generic.List[PSCustomObject]]::new()
$global:currentStep = 0
$processList = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
$installationResults = [System.Collections.Generic.List[PSCustomObject]]::new()


function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to add a step
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
    Write-Host "Step [$global:currentStep/$totalSteps]: $stepDescription" -ForegroundColor Cyan
}

# Function for logging with color coding
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    # Get the PowerShell call stack to determine the actual calling function
    $callStack = Get-PSCallStack
    $callerFunction = if ($callStack.Count -ge 2) { $callStack[1].Command } else { '<Unknown>' }

    # Prepare the formatted message with the actual calling function information
    $formattedMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] [$callerFunction] $Message"

    # Display the log message based on the log level using Write-Host
    switch ($Level.ToUpper()) {
        "DEBUG" { Write-Host $formattedMessage -ForegroundColor DarkGray }
        "INFO" { Write-Host $formattedMessage -ForegroundColor Green }
        "NOTICE" { Write-Host $formattedMessage -ForegroundColor Cyan }
        "WARNING" { Write-Host $formattedMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $formattedMessage -ForegroundColor Red }
        "CRITICAL" { Write-Host $formattedMessage -ForegroundColor Magenta }
        default { Write-Host $formattedMessage -ForegroundColor White }
    }

    # Append to log file
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'setuplab.log')
    $formattedMessage | Out-File -FilePath $logFilePath -Append -Encoding utf8
}

# Function to validate URL
function Test-Url {
    param (
        [string]$url
    )
    try {
        Invoke-RestMethod -Uri $url -Method Head -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Function to get PowerShell path
function Get-PowerShellPath {
    if (Test-Path "C:\Program Files\PowerShell\7\pwsh.exe") {
        return "C:\Program Files\PowerShell\7\pwsh.exe"
    }
    elseif (Test-Path "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe") {
        return "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    }
    else {
        throw "Neither PowerShell 7 nor PowerShell 5 was found on this system."
    }
}


# Function to validate software installation via registry with retry mechanism


# Function to validate software installation via registry with retry mechanism
function Validate-Installation {
    param (
        [string]$SoftwareName,
        [version]$MinVersion = [version]"0.0.0.0",
        [string]$RegistryPath = "",
        [int]$MaxRetries = 3,
        [int]$DelayBetweenRetries = 5  # Delay in seconds
    )

    if ($SoftwareName -eq "RDP") {
        return @{ IsInstalled = $false }  # Force the RDP script to always run
    }

    if ($SoftwareName -eq "Windows Terminal") {
        return @{ IsInstalled = $false }  # Force the Windows Terminal script to always run as it will handle its own validation logic
    }

    $retryCount = 0
    $validationSucceeded = $false

    while ($retryCount -lt $MaxRetries -and -not $validationSucceeded) {
        $registryPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"  # Include HKCU for user-installed apps
        )

        if ($RegistryPath) {
            # If a specific registry path is provided, check only that path
            if (Test-Path $RegistryPath) {
                $app = Get-ItemProperty -Path $RegistryPath -ErrorAction SilentlyContinue
                if ($app -and $app.DisplayName -like "*$SoftwareName*") {
                    $installedVersion = [version]$app.DisplayVersion
                    if ($installedVersion -ge $MinVersion) {
                        $validationSucceeded = $true
                        return @{
                            IsInstalled = $true
                            Version     = $installedVersion
                            ProductCode = $app.PSChildName
                        }
                    }
                }
            }
        }
        else {
            # If no specific registry path, check standard locations
            foreach ($path in $registryPaths) {
                $items = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                foreach ($item in $items) {
                    $app = Get-ItemProperty -Path $item.PsPath -ErrorAction SilentlyContinue
                    if ($app.DisplayName -like "*$SoftwareName*") {
                        $installedVersion = [version]$app.DisplayVersion
                        if ($installedVersion -ge $MinVersion) {
                            $validationSucceeded = $true
                            return @{
                                IsInstalled = $true
                                Version     = $installedVersion
                                ProductCode = $app.PSChildName
                            }
                        }
                    }
                }
            }
        }

        $retryCount++
        if (-not $validationSucceeded) {
            Write-Log "Validation attempt $retryCount failed: $SoftwareName not found or version does not meet minimum requirements. Retrying in $DelayBetweenRetries seconds..." -Level "WARNING"
            Start-Sleep -Seconds $DelayBetweenRetries
        }
    }

    return @{IsInstalled = $false }
}





# Define the GitHub URLs of the scripts and corresponding software names
$scriptDetails = @(
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-7zip.ps1"; SoftwareName = "7-Zip"; MinVersion = [version]"24.07.0.0" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-VSCode.ps1"; SoftwareName = "Visual Studio Code"; MinVersion = [version]"1.82.1.0" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-Everything.ps1"; SoftwareName = "Everything"; MinVersion = [version]"1.4.1.1024" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-FileLocatorPro.ps1"; SoftwareName = "FileLocator Pro"; MinVersion = [version]"8.5.2968" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-Git.ps1"; SoftwareName = "Git"; MinVersion = [version]"2.41.0.0" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-PowerShell7.ps1"; SoftwareName = "PowerShell"; MinVersion = [version]"7.3.6.0" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-GitHubDesktop.ps1"; SoftwareName = "GitHub Desktop"; MinVersion = [version]"3.4.3" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-WindowsTerminal.ps1"; SoftwareName = "Windows Terminal"; MinVersion = [version]"1.20.240626001" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Enable-RDP.ps1"; SoftwareName = "RDP"; MinVersion = [version]"0.0.0.0" } 
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-DockerDesktop.ps1"; SoftwareName = "Docker Desktop"; MinVersion = [version]"4.34.2" } 
)


# Add steps for each script
foreach ($detail in $scriptDetails) {
    Add-Step ("Running script from URL: $($detail.Url)")
}

# Main script execution with try-catch for error handling
try {

    # Elevate to administrator if not already
    if (-not (Test-Admin)) {
        Write-Log "Restarting script with elevated permissions..."
        $startProcessParams = @{
            FilePath     = "powershell.exe"
            ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath)
            Verb         = "RunAs"
        }
        Start-Process @startProcessParams
        exit
    }
    

    $powerShellPath = Get-PowerShellPath

    foreach ($detail in $scriptDetails) {
        $url = $detail.Url
        $softwareName = $detail.SoftwareName
        $minVersion = $detail.MinVersion
        $registryPath = $detail.RegistryPath  # Directly extract RegistryPath

        # Validate before running the installation script
        Write-Log "Validating existing installation of $softwareName..."

        # Pass RegistryPath if it's available
        $installationCheck = if ($registryPath) {
            Validate-Installation -SoftwareName $softwareName -MinVersion $minVersion -MaxRetries 3 -DelayBetweenRetries 5 -RegistryPath $registryPath
        }
        else {
            Validate-Installation -SoftwareName $softwareName -MinVersion $minVersion -MaxRetries 3 -DelayBetweenRetries 5
        }

        if ($installationCheck.IsInstalled) {
            Write-Log "$softwareName version $($installationCheck.Version) is already installed. Skipping installation." -Level "INFO"
            $installationResults.Add([pscustomobject]@{ SoftwareName = $softwareName; Status = "Already Installed"; VersionFound = $installationCheck.Version })
        }
        else {
            if (Test-Url -url $url) {
                Log-Step
                Write-Log "Running script from URL: $url" -Level "INFO"
                # $process = Start-Process -FilePath $powerShellPath -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "Invoke-Expression (Invoke-RestMethod -Uri '$url')") -Verb RunAs -PassThru

                $startProcessParams = @{
                    FilePath     = $powerShellPath
                    ArgumentList = @(
                        "-NoExit",
                        "-NoProfile",
                        "-ExecutionPolicy", "Bypass",
                        "-Command", "Invoke-Expression (Invoke-RestMethod -Uri '$url')"
                    )
                    Verb         = "RunAs"
                    PassThru     = $true
                }
                
                $process = Start-Process @startProcessParams
                
                $processList.Add($process)

                $installationResults.Add([pscustomobject]@{ SoftwareName = $softwareName; Status = "Installed"; VersionFound = "N/A" })
            }
            else {
                Write-Log "URL $url is not accessible" -Level "ERROR"
                $installationResults.Add([pscustomobject]@{ SoftwareName = $softwareName; Status = "Failed - URL Not Accessible"; VersionFound = "N/A" })
            }
        }
    }

    # Wait for all processes to complete
    foreach ($process in $processList) {
        $process.WaitForExit()
    }

    # Post-installation validation
    foreach ($result in $installationResults) {
        if ($result.Status -eq "Installed") {
            if ($result.SoftwareName -in @("RDP", "Windows Terminal")) {
                Write-Log "Skipping post-installation validation for $($result.SoftwareName)." -Level "INFO"
                $result.Status = "Successfully Installed"
                continue
            }

            Write-Log "Validating installation of $($result.SoftwareName)..."
            $validationResult = Validate-Installation -SoftwareName $result.SoftwareName -MinVersion ($scriptDetails | Where-Object { $_.SoftwareName -eq $result.SoftwareName }).MinVersion

            if ($validationResult.IsInstalled) {
                Write-Log "Validation successful: $($result.SoftwareName) version $($validationResult.Version) is installed." -Level "INFO"
                $result.VersionFound = $validationResult.Version
                $result.Status = "Successfully Installed"
            }
            else {
                Write-Log "Validation failed: $($result.SoftwareName) was not found on the system." -Level "ERROR"
                $result.Status = "Failed - Not Found After Installation"
            }
        }
    }


    # Summary report
    $totalSoftware = $installationResults.Count
    $successfulInstallations = $installationResults | Where-Object { $_.Status -eq "Successfully Installed" }
    $alreadyInstalled = $installationResults | Where-Object { $_.Status -eq "Already Installed" }
    $failedInstallations = $installationResults | Where-Object { $_.Status -like "Failed*" }

    Write-Host "Total Software: $totalSoftware" -ForegroundColor Cyan
    Write-Host "Successful Installations: $($successfulInstallations.Count)" -ForegroundColor Green
    Write-Host "Already Installed: $($alreadyInstalled.Count)" -ForegroundColor Yellow
    Write-Host "Failed Installations: $($failedInstallations.Count)" -ForegroundColor Red

    # Detailed Summary
    Write-Host "`nDetailed Summary:" -ForegroundColor Cyan
    $installationResults | ForEach-Object {
        Write-Host "Software: $($_.SoftwareName)" -ForegroundColor White
        Write-Host "Status: $($_.Status)" -ForegroundColor White
        Write-Host "Version Found: $($_.VersionFound)" -ForegroundColor White
        Write-Host "----------------------------------------" -ForegroundColor Gray
    }
}
catch {
    # Capture the error details
    $errorDetails = $_ | Out-String
    Write-Log "An error occurred: $errorDetails" -Level "ERROR"
    throw
}


# Keep the PowerShell window open to review the logs
Read-Host 'Press Enter to close this window...'