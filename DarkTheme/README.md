# Windows Theme Setter PowerShell Script

This directory contains a PowerShell script (`Set-WindowsTheme.ps1`) to programmatically change the Windows 11 theme between light and dark modes.

## Features

- Sets both application and system themes.
- Option to automatically restart Windows Explorer to apply system theme changes immediately.
- Simple command-line interface.
- Includes comment-based help for easy understanding and usage.

## Script: `Set-WindowsTheme.ps1`

This script modifies registry entries under `HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize` to switch between light and dark themes.

### Parameters

-   `Mode` (string):
    -   Specifies the theme to set.
    -   Accepted values: `"dark"`, `"light"`.
    -   Default: `"dark"`.
-   `RestartExplorer` (boolean):
    -   If `$true`, Windows Explorer will be restarted after the theme is set. This ensures that changes to the system UI (taskbar, Start Menu, etc.) are applied immediately.
    -   Default: `$false`.

### How to Use

1.  Open PowerShell.
2.  Navigate to the directory containing the script (e.g., `cd C:\Code\Windows\DarkTheme`).
3.  Run the script with desired parameters. You can also get help for the script:
    ```powershell
    Get-Help .\Set-WindowsTheme.ps1 -Full
    ```

**Examples:**

*   **Set to Dark Mode (default behavior):**
    ```powershell
    .\Set-WindowsTheme.ps1
    ```
    or explicitly:
    ```powershell
    .\Set-WindowsTheme.ps1 -Mode dark
    ```

*   **Set to Light Mode and automatically restart Explorer:**
    ```powershell
    .\Set-WindowsTheme.ps1 -Mode light -RestartExplorer $true
    ```

*   **Set to Light Mode without restarting Explorer:**
    ```powershell
    .\Set-WindowsTheme.ps1 -Mode light
    # or
    .\Set-WindowsTheme.ps1 -Mode light -RestartExplorer $false
    ```

### Notes

-   The script modifies user-specific theme settings and generally does not require administrative privileges.
-   If you choose not to use the `-RestartExplorer $true` parameter (or if it's omitted, as it defaults to `$false`), you might need to manually restart Windows Explorer (e.g., via Task Manager) or sign out and back in for all system theme changes (like the taskbar and Start Menu) to take full effect. 