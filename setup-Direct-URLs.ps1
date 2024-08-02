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

# Function to execute scripts with retry
function Execute-ScriptWithRetry {
    param (
        [string]$url,
        [int]$maxRetries = 3,
        [string]$powerShellPath
    )
    $attempt = 0
    $success = $false

    while ($attempt -lt $maxRetries -and -not $success) {
        try {
            $attempt++
            $scriptContent = Invoke-RestMethod -Uri $url
            $scriptPath = [System.IO.Path]::Combine($env:TEMP, [System.IO.Path]::GetFileName($url))
            $scriptContent | Out-File -FilePath $scriptPath -Encoding utf8

            $startProcessParams = @{
                FilePath     = $powerShellPath
                ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath)
                Verb         = "RunAs"
            }
            Start-Process @startProcessParams -Wait

            Write-Log "Script executed successfully: $url" -Level "INFO"
            $success = $true
        } catch {
            Write-Log "Attempt $attempt failed for script $url $_" -Level "ERROR"
            if ($attempt -eq $maxRetries) {
                throw "Maximum retry attempts reached for script $url."
            }
            Start-Sleep -Seconds 5
        }
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

# Define the GitHub URLs of the scripts
$scriptUrls = @(
    "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-VSCode.ps1",
    "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-Everything.ps1",
    "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-FileLocatorPro.ps1",
    "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-Git.ps1",
    "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-PowerShell7.ps1",
    "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-GitHubDesktop.ps1",
    "https://raw.githubusercontent.com/aollivierre/setuplab/main/Install-WindowsTerminal.ps1",
    "https://raw.githubusercontent.com/aollivierre/setuplab/main/Enable-RDP.ps1"
)

# Add steps for each script
foreach ($url in $scriptUrls) {
    Add-Step ("Running script from URL: $url")
}

# Main script execution with try-catch for error handling
try {
    $powerShellPath = Get-PowerShellPath

    foreach ($url in $scriptUrls) {
        if (Test-Url -url $url) {
            Log-Step
            Write-Log "Running script from URL: $url"
            $startProcessParams = @{
                FilePath     = $powerShellPath
                ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "Invoke-Expression (Invoke-RestMethod -Uri '$url')")
                Verb         = "RunAs"
            }
            Start-Process @startProcessParams
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
