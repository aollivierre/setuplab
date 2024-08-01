# call using:

# powershell -Command "iex (irm https://github.com/aollivierre/setuplab/blob/main/setup.ps1)"
# powershell -Command "iex (irm https://bit.ly/4doEQ7P)"
# powershell -Command "iex (irm bit.ly/4doEQ7P)"

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

# Download-And-Extract-SetupLab.ps1
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
    Invoke-WebRequest -Uri $repoUrl -OutFile $zipPath
    Write-Host "Download complete."

    Write-Host "Extracting SetupLab repository..."
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
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
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$extractedPath\Install-VSCode.ps1`""

    # $DBG

    # Step 3: Install Everything
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$extractedPath\Install-Everything.ps1`""

    # Step 4: Install FileLocator Pro
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$extractedPath\Install-FileLocatorPro.ps1`""

    # Step 5: Install Git
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$extractedPath\Install-Git.ps1`""

    # Step 6: Install PowerShell 7
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$extractedPath\Install-PowerShell7.ps1`""

    # Step 7: Install GitHub Desktop
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$extractedPath\Install-GitHubDesktop.ps1`""

    # Step 8: Install Windows Terminal
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$extractedPath\Install-WindowsTerminal.ps1`""

    # Step 9 : Enable RDP
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$extractedPath\Enable-RDP.ps1`""

}
catch {
    # Capture the error details
    $errorDetails = $_ | Out-String
    Write-Host "An error occurred: $errorDetails" -ForegroundColor Red
    throw
}
