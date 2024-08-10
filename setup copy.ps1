# Initialize the global steps list
$global:steps = [System.Collections.Generic.List[PSCustomObject]]::new()
$global:currentStep = 0

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
    Write-Host "Step [$global:currentStep/$totalSteps]: $stepDescription"
}

# Function for logging
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage

    # Append to log file
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'install-scripts.log')
    $logMessage | Out-File -FilePath $logFilePath -Append -Encoding utf8
}

# Function to validate URL
function Test-Url {
    param (
        [string]$url
    )
    try {
        Invoke-RestMethod -Uri $url -Method Head -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Function to get PowerShell path
function Get-PowerShellPath {
    if (Test-Path "C:\Program Files\PowerShell\7\pwsh.exe") {
        return "C:\Program Files\PowerShell\7\pwsh.exe"
    } elseif (Test-Path "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe") {
        return "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    } else {
        throw "Neither PowerShell 7 nor PowerShell 5 was found on this system."
    }
}

# Function to validate software installation via registry
function Validate-Installation {
    param (
        [string]$SoftwareName,
        [version]$MinVersion = [version]"0.0.0.0"
    )

    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($path in $registryPaths) {
        $items = Get-ChildItem -Path $path -ErrorAction SilentlyContinue

        foreach ($item in $items) {
            $app = Get-ItemProperty -Path $item.PsPath -ErrorAction SilentlyContinue
            if ($app.DisplayName -like "*$SoftwareName*") {
                $installedVersion = [version]$app.DisplayVersion
                if ($installedVersion -ge $MinVersion) {
                    return @{
                        IsInstalled = $true
                        Version = $installedVersion
                        ProductCode = $app.PSChildName
                    }
                }
            }
        }
    }

    return @{IsInstalled = $false}
}

# Define the GitHub URLs of the scripts and corresponding software names
$scriptDetails = @(
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-7zip.ps1"; SoftwareName = "7-Zip"; MinVersion = [version]"24.07.0.0" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-VSCode.ps1"; SoftwareName = "Visual Studio Code"; MinVersion = [version]"1.92.1.0" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-Everything.ps1"; SoftwareName = "Everything"; MinVersion = [version]"1.4.1.1024" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-FileLocatorPro.ps1"; SoftwareName = "FileLocator Pro"; MinVersion = [version]"8.0.0.0" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-Git.ps1"; SoftwareName = "Git"; MinVersion = [version]"2.0.0.0" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-PowerShell7.ps1"; SoftwareName = "PowerShell"; MinVersion = [version]"7.0.0.0" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-GitHubDesktop.ps1"; SoftwareName = "GitHub Desktop"; MinVersion = [version]"2.0.0.0" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-WindowsTerminal.ps1"; SoftwareName = "Windows Terminal"; MinVersion = [version]"1.0.0.0" },
    @{ Url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/Enable-RDP.ps1"; SoftwareName = "RDP"; MinVersion = [version]"0.0.0.0" } # Adjust for actual validation, if possible
)

# Add steps for each script
foreach ($detail in $scriptDetails) {
    Add-Step ("Running script from URL: $($detail.Url)")
}

# Main script execution with try-catch for error handling
try {
    $powerShellPath = Get-PowerShellPath

    foreach ($detail in $scriptDetails) {
        $url = $detail.Url
        $softwareName = $detail.SoftwareName
        $minVersion = $detail.MinVersion

        if (Test-Url -url $url) {
            Log-Step
            Write-Log "Running script from URL: $url"
            $startProcessParams = @{
                FilePath     = $powerShellPath
                ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "Invoke-Expression (Invoke-RestMethod -Uri '$url')")
                Verb         = "RunAs"
            }
            Start-Process @startProcessParams | Wait-Process

            # Validate installation
            Write-Log "Validating installation of $softwareName..."
            $installationCheck = Validate-Installation -SoftwareName $softwareName -MinVersion $minVersion
            if ($installationCheck.IsInstalled) {
                Write-Log "Validation successful: $softwareName version $($installationCheck.Version) is installed."
            } else {
                Write-Log "Validation failed: $softwareName was not found on the system." -Level "ERROR"
            }
        } else {
            Write-Log "URL $url is not accessible" -Level "ERROR"
        }
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
