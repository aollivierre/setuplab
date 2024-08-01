function Enable-RDP {
    # Enable RDP by setting the necessary registry keys
    Write-Host "Enabling Remote Desktop..."
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0

    # Enable the RDP firewall rule
    Write-Host "Enabling RDP firewall rule..."
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

    # Add "Everyone" to Remote Desktop Users group using net localgroup command
    Write-Host "Adding 'Everyone' to Remote Desktop Users group..."
    net localgroup "Remote Desktop Users" "Everyone" /add | Out-Null

    # Validate RDP is enabled
    $rdpEnabled = (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections").fDenyTSConnections -eq 0
    if ($rdpEnabled) {
        Write-Host "RDP is enabled successfully."
    } else {
        Write-Host "Failed to enable RDP." -ForegroundColor Red
        return
    }

    # Validate "Everyone" is in the Remote Desktop Users group
    $groupMembers = net localgroup "Remote Desktop Users"
    $everyoneAdded = $groupMembers -match "Everyone"
    if ($everyoneAdded) {
        Write-Host "'Everyone' is successfully added to the Remote Desktop Users group."
    } else {
        Write-Host "Failed to add 'Everyone' to the Remote Desktop Users group." -ForegroundColor Red
    }

    Write-Host "Remote Desktop enabled and 'Everyone' added to Remote Desktop Users group."
}

# Example usage of the function
Enable-RDP
