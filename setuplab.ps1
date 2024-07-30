#call using powershell -Command "iex (irm https://raw.githubusercontent.com/aollivierre/Forticlient/main/Setup.ps1)"
#call using powershell -Command "iex (irm https://bit.ly/4doEQ7P)"
#call using powershell -Command "iex (irm bit.ly/4doEQ7P)"


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


# Download-And-Extract-SetupLab
function Download-And-Extract-SetupLab {
    param (
        [string]$repoUrl,
        [string]$destination
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

    # Use robocopy to move contents to the final destination
    Write-Host "Copying extracted files to $destination..."
    $robocopyArgs = "$extractPath\* $destination /E /MOVE /COPYALL /R:3 /W:10"
    Start-Process -FilePath robocopy.exe -ArgumentList $robocopyArgs -Wait
    Write-Host "Files copied to $destination."

    # Clean up temporary files
    Remove-Item -Path $zipPath -Force
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
    $DownloadAndExtractSetupLabParams = @{
        repoUrl = "https://github.com/aollivierre/setuplab/archive/refs/heads/main.zip"
        destination = $PSScriptRoot
    }
    Download-And-Extract-SetupLab @DownloadAndExtractSetupLabParams

    # Step 2: Install Visual Studio Code
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$scriptRoot\Install-VSCode.ps1`""

    # Step 3: Install Everything
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$scriptRoot\Install-Everything.ps1`""

    # Step 4: Install FileLocator Pro
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$scriptRoot\Install-FileLocatorPro.ps1`""

    # Step 5: Install Git
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$scriptRoot\Install-Git.ps1`""

    # Step 6: Install PowerShell 7
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$scriptRoot\Install-PowerShell7.ps1`""

    # Step 7: Install GitHub Desktop
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$scriptRoot\Install-GitHubDesktop.ps1`""

    # Step 8: Install Windows Terminal
    Log-Step
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$scriptRoot\Install-WindowsTerminal.ps1`""

} catch {
    # Capture the error details
    $errorDetails = $_ | Out-String
    Write-Host "An error occurred: $errorDetails" -ForegroundColor Red
    throw
}