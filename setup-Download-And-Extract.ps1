# call using:
# powershell -Command "iex (irm https://raw.githubusercontent.com/aollivierre/setuplab/main/setup.ps1)"
# powershell -Command "iex (irm https://bit.ly/4c3XH76)"
# powershell -Command "iex (irm bit.ly/4c3XH76)"
# or if you are in powershell already call (URL is case sensitive)
# iex (irm bit.ly/4c3XH76)

# Define a temporary folder path with timestamp
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$tempFolder = "$env:TEMP\SetupLab_$timestamp"

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

# Function to download and extract SetupLab repository
function Download-And-Extract-SetupLab {
    param (
        [string]$repoUrl = "https://github.com/aollivierre/setuplab/archive/refs/heads/main.zip",
        [string]$destination
    )

    if (-not $destination) {
        throw "Destination path cannot be empty."
    }

    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $zipPath = "$env:TEMP\SetupLab_$timestamp.zip"
    $extractPath = "$env:TEMP\SetupLab_$timestamp"

    Write-Host "Downloading SetupLab repository from GitHub..."
    $invokeWebRequestParams = @{
        Uri     = $repoUrl
        OutFile = $zipPath
    }
    Invoke-WebRequest @invokeWebRequestParams
    Write-Host "Download complete."

    Write-Host "Extracting SetupLab repository..."
    $expandArchiveParams = @{
        Path           = $zipPath
        DestinationPath = $extractPath
        Force          = $true
    }
    Expand-Archive @expandArchiveParams
    Write-Host "Extraction complete."

    # Return the extraction path
    return "$extractPath\setuplab-main"
}

# Define the steps before execution
Add-Step "Download and Extract SetupLab repository"
Add-Step "Install Visual Studio Code"
Add-Step "Install Everything"
Add-Step "Install FileLocator Pro"
Add-Step "Install Git"
Add-Step "Install PowerShell 7"
Add-Step "Install GitHub Desktop"
Add-Step "Install Windows Terminal"
Add-Step "Enable RDP"

# Main script execution with try-catch for error handling
try {
    # Step 1: Download and Extract Setup Lab
    Log-Step
    $params = @{
        repoUrl     = "https://github.com/aollivierre/setuplab/archive/refs/heads/main.zip"
        destination = $tempFolder
    }
    $extractedPath = Download-And-Extract-SetupLab @params

    # Step 2: Install Visual Studio Code
    Log-Step
    $startProcessParams = @{
        FilePath     = "powershell.exe"
        ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "$extractedPath\Install-VSCode.ps1")
    }
    Start-Process @startProcessParams

    # Step 3: Install Everything
    Log-Step
    $startProcessParams = @{
        FilePath     = "powershell.exe"
        ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "$extractedPath\Install-Everything.ps1")
    }
    Start-Process @startProcessParams

    # Step 4: Install FileLocator Pro
    Log-Step
    $startProcessParams = @{
        FilePath     = "powershell.exe"
        ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "$extractedPath\Install-FileLocatorPro.ps1")
    }
    Start-Process @startProcessParams

    # Step 5: Install Git
    Log-Step
    $startProcessParams = @{
        FilePath     = "powershell.exe"
        ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "$extractedPath\Install-Git.ps1")
    }
    Start-Process @startProcessParams

    # Step 6: Install PowerShell 7
    Log-Step
    $startProcessParams = @{
        FilePath     = "powershell.exe"
        ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "$extractedPath\Install-PowerShell7.ps1")
    }
    Start-Process @startProcessParams

    # Step 7: Install GitHub Desktop
    Log-Step
    $startProcessParams = @{
        FilePath     = "powershell.exe"
        ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "$extractedPath\Install-GitHubDesktop.ps1")
    }
    Start-Process @startProcessParams

    # Step 8: Install Windows Terminal
    Log-Step
    $startProcessParams = @{
        FilePath     = "powershell.exe"
        ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "$extractedPath\Install-WindowsTerminal.ps1")
    }
    Start-Process @startProcessParams

    # Step 9: Enable RDP
    Log-Step
    $startProcessParams = @{
        FilePath     = "powershell.exe"
        ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "$extractedPath\Enable-RDP.ps1")
    }
    Start-Process @startProcessParams

}
catch {
    # Capture the error details
    $errorDetails = $_ | Out-String
    Write-Host "An error occurred: $errorDetails" -ForegroundColor Red
    throw
}


