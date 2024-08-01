# Install-PowerShell7.ps1

# Function to check if running as administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Elevate to administrator if not already
if (-not (Test-Admin)) {
    Write-Host "Restarting script with elevated permissions..."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Function to install the latest PowerShell
function Install-PowerShell7 {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    # Get the latest release info
    $url = (Invoke-RestMethod https://api.github.com/repos/PowerShell/PowerShell/releases/latest).assets | 
           Where-Object { $_.name -like '*win-x64.msi' } | 
           Select-Object -ExpandProperty browser_download_url

    Write-Host "Downloading PowerShell from $url"

    # Define the destination path
    $destination = "$env:TEMP\pwsh.msi"

    # Download the file using BITS
    Start-BitsTransfer -Source $url -Destination $destination -Description "Downloading PowerShell MSI"

    Write-Host "Installing PowerShell..."

    # Install the downloaded MSI package
    $installProcess = Start-Process -FilePath msiexec.exe -ArgumentList "/i $destination /quiet /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1" -Wait -PassThru

    # Check the exit code of the MSI installation
    if ($installProcess.ExitCode -eq 0) {
        Write-Host "PowerShell installation completed successfully."
    } else {
        Write-Host "PowerShell installation failed. Exit code: $($installProcess.ExitCode)"
        Write-Host "Refer to the log file for more details."
    }
}

# Call the Install-PowerShell7 function
Install-PowerShell7
