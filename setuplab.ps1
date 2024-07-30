# call using:

# powershell -Command "iex (irm https://raw.githubusercontent.com/aollivierre/Forticlient/main/Setup.ps1)"
# powershell -Command "iex (irm https://bit.ly/4doEQ7P)"
# powershell -Command "iex (irm bit.ly/4doEQ7P)"


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


# Copy-With-Logging.ps1
function Copy-With-Logging {
    param (
        [string]$source,
        [string]$destination,
        [string]$logFile
    )

    # Define the full path to robocopy.exe
    $robocopyPath = "C:\Windows\System32\robocopy.exe"

    # Ensure the base destination directory exists
    if (-Not (Test-Path -Path $destination)) {
        New-Item -Path $destination -ItemType Directory -Force
    }

    # Execute robocopy with logging
    Start-Process -FilePath $robocopyPath -ArgumentList "$source", "$destination", "/E", "/LOG:$logFile" -Wait -NoNewWindow

    Write-Host "Copy with logging from $source to $destination executed."
}



# Download-And-Extract-SetupLab.ps1
function Download-And-Extract-SetupLab {
    param (
        [string]$repoUrl = "https://github.com/aollivierre/setuplab/archive/refs/heads/main.zip",
        [string]$destination,
        [string]$logFile
    )

    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $zipPath = "$env:TEMP\SetupLab_$timestamp.zip"
    $extractPath = "$env:TEMP\SetupLab_$timestamp"

    Write-Host "Downloading SetupLab repository from GitHub..."
    Invoke-WebRequest -Uri $repoUrl -OutFile $zipPath
    Write-Host "Download complete."

    Write-Host "Extracting SetupLab repository..."
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Host "Extraction complete."

    # Call Copy-With-Logging function
    Copy-With-Logging -source "$extractPath\setuplab-main" -destination $destination -logFile $logFile

    # Clean up temporary files
    Remove-Item -Path $zipPath -Force
    Remove-Item -Path $extractPath -Recurse -Force
    Write-Host "Clean up complete."
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

# Main script execution with try-catch for error handling
try {

    # Step 1: Download and Extract Setup Lab
    Log-Step
    $params = @{
        repoUrl = "https://github.com/aollivierre/setuplab/archive/refs/heads/main.zip"
        destination = "$PSscriptRoot"
        logFile = "$PSscriptRoot\SetupLabCopy.log"
    }
    Download-And-Extract-SetupLab @params
    # Step 2: Install Visual Studio Code
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSscriptRoot\Install-VSCode.ps1`""

    # Step 3: Install Everything
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSscriptRoot\Install-Everything.ps1`""

    # Step 4: Install FileLocator Pro
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSscriptRoot\Install-FileLocatorPro.ps1`""

    # Step 5: Install Git
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSscriptRoot\Install-Git.ps1`""

    # Step 6: Install PowerShell 7
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSscriptRoot\Install-PowerShell7.ps1`""

    # Step 7: Install GitHub Desktop
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSscriptRoot\Install-GitHubDesktop.ps1`""

    # Step 8: Install Windows Terminal
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSscriptRoot\Install-WindowsTerminal.ps1`""

} catch {
    # Capture the error details
    $errorDetails = $_ | Out-String
    Write-Host "An error occurred: $errorDetails" -ForegroundColor Red
    throw
}