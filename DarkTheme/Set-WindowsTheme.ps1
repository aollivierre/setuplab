<#
.SYNOPSIS
    Toggles the Windows theme between light and dark mode.
.DESCRIPTION
    This script modifies the necessary registry settings to switch the Windows
    system and application themes to either light or dark mode.
    It also provides an option to restart Windows Explorer to apply system-wide
    changes immediately.
.PARAMETER Mode
    Specifies the desired theme mode. Accepted values are "dark" or "light".
    Defaults to "dark".
.PARAMETER RestartExplorer
    If set to $true, Windows Explorer will be restarted after applying the theme
    to ensure system-wide changes (like taskbar and Start menu) are immediately visible.
    Defaults to $false.
.EXAMPLE
    .\Set-WindowsTheme.ps1 -Mode dark
    Sets the Windows theme to dark mode. Explorer will not be restarted automatically.
.EXAMPLE
    .\Set-WindowsTheme.ps1 -Mode light -RestartExplorer $true
    Sets the Windows theme to light mode and restarts Windows Explorer.
.NOTES
    Author: Gemini
    This script directly modifies user-level registry settings.
#>
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dark", "light")]
    [string]$Mode = "dark", # Default to dark mode if no mode is specified

    [Parameter(Mandatory=$false)]
    [bool]$RestartExplorer = $false # Default to not restarting Explorer
)

#region Initialization
# Define the registry path for theme settings
$RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"

# Define the registry value names
$AppsThemeValueName = "AppsUseLightTheme"
$SystemThemeValueName = "SystemUsesLightTheme"

# Determine the value to set based on the chosen mode
# A value of 0 corresponds to dark mode, and 1 to light mode.
$ThemeValueToSet = if ($Mode -eq "dark") { 0 } else { 1 }
#endregion Initialization

#region Logic
try {
    # Inform the user about the action being taken
    Write-Host "Attempting to set Windows theme to $($Mode.ToUpper()) mode..."

    # Set the application theme
    # This registry key controls the theme for applications that support light/dark mode.
    Set-ItemProperty -Path $RegistryPath -Name $AppsThemeValueName -Value $ThemeValueToSet -ErrorAction Stop
    Write-Host "- Application theme set to $Mode mode."

    # Set the system theme
    # This registry key controls the theme for system elements like the Taskbar, Start Menu, and Action Center.
    Set-ItemProperty -Path $RegistryPath -Name $SystemThemeValueName -Value $ThemeValueToSet -ErrorAction Stop
    Write-Host "- System theme set to $Mode mode."

    # Check if the user wants to restart Explorer
    if ($RestartExplorer) {
        Write-Host "Restarting Windows Explorer to apply system theme changes immediately..."
        # Stop the Explorer process. -Force is used to ensure it closes.
        # -ErrorAction SilentlyContinue is used in case Explorer is not running or has multiple instances,
        # though typically there is one main shell process.
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        
        # Start the Explorer process. This will reload the shell (taskbar, desktop icons, etc.)
        Start-Process explorer -ErrorAction Stop
        Write-Host "Windows Explorer restarted successfully."
    } else {
        Write-Host "Note: System-wide theme changes (e.g., Taskbar) may require a Windows Explorer restart or a sign-out/sign-in to fully apply."
    }

    Write-Host "Windows theme successfully set to $Mode mode."
}
catch {
    # Error handling block
    # This will catch any terminating errors from the Set-ItemProperty or Start-Process cmdlets.
    Write-Error "An error occurred while attempting to set the theme: $($_.Exception.Message)"
    Write-Error "Please ensure you have the necessary permissions and that the registry path is correct."
}
#endregion Logic 