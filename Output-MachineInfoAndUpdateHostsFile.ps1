function Output-MachineInfoAndUpdateHostsFile {
    param (
        [string]$remoteHostFilePath = "\\lab-hv01\etc\hosts"
    )

    # Output machine information to the console
    Write-Host "Gathering machine information..."
    
    $computerName = $env:COMPUTERNAME
    $ipAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" }).IPAddress
    $os = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
    $uptime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime

    Write-Host "Computer Name: $computerName"
    Write-Host "IP Address: $ipAddress"
    Write-Host "Operating System: $os"
    Write-Host "Uptime: $uptime"

    # Prepare the entry to add to the remote hosts file
    $hostEntry = "$ipAddress`t$computerName"

    # Read the existing remote hosts file
    Write-Host "Reading remote hosts file..."
    $remoteHostsFileContent = Get-Content -Path $remoteHostFilePath

    # Check if the entry already exists in the remote hosts file
    if ($remoteHostsFileContent -notcontains $hostEntry) {
        Write-Host "Updating remote hosts file..."
        # Add the new entry to the remote hosts file
        Add-Content -Path $remoteHostFilePath -Value $hostEntry
        Write-Host "Hosts file updated on remote machine."
    } else {
        Write-Host "Host entry already exists in the remote hosts file."
    }
}

# Example usage of the function
Output-MachineInfoAndUpdateHostsFile
