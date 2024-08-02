# Function to check if running as administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'enable-rdp.log')
    $logMessage | Out-File -FilePath $logFilePath -Append -Encoding utf8
}

# Function to check and add user to group if not present
function Add-UserToGroupIfNotPresent {
    param (
        [string]$groupName,
        [string]$userName
    )

    try {
        Write-Log "Checking if user '$userName' is a member of group '$groupName'..."
        $userExists = Get-LocalGroupMember -Group $groupName -ErrorAction Stop | Where-Object { $_.Name -eq $userName }

        if ($userExists) {
            Write-Log "User '$userName' is already a member of group '$groupName'." -Level "INFO"
        } else {
            Write-Log "User '$userName' is NOT a member of group '$groupName'. Adding user to the group..." -Level "INFO"
            Add-LocalGroupMember -Group $groupName -Member $userName
            Write-Log "User '$userName' has been added to group '$groupName'." -Level "INFO"
        }
    } catch {
        if ($_.Exception.Message -match "is already a member of group") {
            Write-Log "User '$userName' is already a member of group '$groupName'." -Level "INFO"
        } else {
            Write-Log "Failed to check or add user '$userName' to group '$groupName'. Error: $_" -Level "ERROR"
        }
    }
}

# Function to verify user permissions in the group
function Verify-Permissions {
    param (
        [string]$groupName,
        [string]$userName
    )

    Write-Log "Verifying permissions for user '$userName' in group '$groupName'..."

    try {
        $member = Get-LocalGroupMember -Group $groupName -ErrorAction Stop | Where-Object { $_.Name -eq $userName }
        if ($member) {
            Write-Log "User '$userName' has the necessary permissions in the group '$groupName'." -Level "INFO"
        } else {
            Write-Log "User '$userName' does NOT have the necessary permissions in the group '$groupName'." -Level "ERROR"
        }
    } catch {
        Write-Log "Failed to verify permissions for user '$userName' in group '$groupName'. Error: $_" -Level "ERROR"
    }
}

function Enable-RDP {
    try {
        # Enable RDP by setting the necessary registry keys
        Write-Log "Enabling Remote Desktop..."
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0

        # Enable the RDP firewall rule
        Write-Log "Enabling RDP firewall rule..."
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

        # Add "Everyone" to Remote Desktop Users group using net localgroup command
        Write-Log "Adding 'Everyone' to Remote Desktop Users group..."
        net localgroup "Remote Desktop Users" "Everyone" /add | Out-Null

        # Validate RDP is enabled
        $rdpEnabled = (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections").fDenyTSConnections -eq 0
        if ($rdpEnabled) {
            Write-Log "RDP is enabled successfully."
        } else {
            Write-Log "Failed to enable RDP." -Level "ERROR"
            return
        }

        # Validate "Everyone" is in the Remote Desktop Users group
        $groupMembers = net localgroup "Remote Desktop Users"
        $everyoneAdded = $groupMembers -match "Everyone"
        if ($everyoneAdded) {
            Write-Log "'Everyone' is successfully added to the Remote Desktop Users group."
        } else {
            Write-Log "Failed to add 'Everyone' to the Remote Desktop Users group." -Level "ERROR"
        }

        Write-Log "Remote Desktop enabled and 'Everyone' added to Remote Desktop Users group."
    } catch {
        Write-Log "An error occurred: $_" -Level "ERROR"
    }

    # Prevent the window from closing immediately
    Read-Host 'Press Enter to close this window...'
}

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

# Enable RDP and add "Everyone" to the Remote Desktop Users group
Enable-RDP
