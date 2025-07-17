# Initialize the total and completed steps
$totalSteps = 5
$completedSteps = 0

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

    # Get the PowerShell call stack to determine the actual calling function
    $callStack = Get-PSCallStack
    $callerFunction = if ($callStack.Count -ge 2) { $callStack[1].Command } else { '<Unknown>' }

    # Prepare the formatted message with the actual calling function information
    $formattedMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] [$callerFunction] $Message"

    # Display the log message based on the log level using Write-Host
    switch ($Level.ToUpper()) {
        "DEBUG" { Write-Host $formattedMessage -ForegroundColor DarkGray }
        "INFO" { Write-Host $formattedMessage -ForegroundColor Green }
        "NOTICE" { Write-Host $formattedMessage -ForegroundColor Cyan }
        "WARNING" { Write-Host $formattedMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $formattedMessage -ForegroundColor Red }
        "CRITICAL" { Write-Host $formattedMessage -ForegroundColor Magenta }
        default { Write-Host $formattedMessage -ForegroundColor White }
    }

    # Append to log file
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'Enable-RDP.log')
    $formattedMessage | Out-File -FilePath $logFilePath -Append -Encoding utf8
}
# Function to validate RDP and "Everyone" group membership
function Validate-RDPConfiguration {
    $rdpEnabled = (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections").fDenyTSConnections -eq 0
    $groupMembers = net localgroup "Remote Desktop Users"
    $everyoneAdded = $groupMembers -match "Everyone"

    return @{
        IsRDPEnabled = $rdpEnabled
        IsEveryoneAdded = $everyoneAdded
    }
}

# Function to enable RDP and configure "Everyone" group membership
function Enable-RDP {
    # Step 1: Pre-configuration validation
    Write-Log "Step 1: Validating if RDP is already enabled and 'Everyone' is in the Remote Desktop Users group..."
    $preConfigCheck = Validate-RDPConfiguration
    if ($preConfigCheck.IsRDPEnabled -and $preConfigCheck.IsEveryoneAdded) {
        Write-Log "RDP is already enabled and 'Everyone' is already in the Remote Desktop Users group." -Level "INFO"
        return
    }
    $completedSteps++

    # Step 2: Enable RDP by setting the necessary registry keys
    Write-Log "Step 2: Enabling RDP by setting the necessary registry keys..."
    try {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
        Write-Log "RDP is now enabled." -Level "INFO"
    }
    catch {
        Write-Log "Failed to enable RDP: $_" -Level "ERROR"
        return
    }
    $completedSteps++

    # Step 3: Enable the RDP firewall rule
    Write-Log "Step 3: Enabling RDP firewall rule..."
    try {
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        Write-Log "RDP firewall rule enabled." -Level "INFO"
    }
    catch {
        Write-Log "Failed to enable RDP firewall rule: $_" -Level "ERROR"
        return
    }
    $completedSteps++

    # Step 4: Add "Everyone" to the Remote Desktop Users group
    Write-Log "Step 4: Adding 'Everyone' to the Remote Desktop Users group..."
    try {
        net localgroup "Remote Desktop Users" "Everyone" /add | Out-Null
        Write-Log "'Everyone' added to the Remote Desktop Users group." -Level "INFO"
    }
    catch {
        Write-Log "Failed to add 'Everyone' to the Remote Desktop Users group: $_" -Level "ERROR"
        return
    }
    $completedSteps++

    # Step 5: Post-configuration validation with retry mechanism
    Write-Log "Step 5: Validating RDP and 'Everyone' in the Remote Desktop Users group after enabling..."
    $maxRetries = 3
    $retryCount = 0
    $delayBetweenRetries = 5  # Delay in seconds

    $validationSucceeded = $false
    while ($retryCount -lt $maxRetries -and -not $validationSucceeded) {
        Start-Sleep -Seconds $delayBetweenRetries  # Wait before checking
        $postConfigCheck = Validate-RDPConfiguration
        if ($postConfigCheck.IsRDPEnabled -and $postConfigCheck.IsEveryoneAdded) {
            Write-Log "Validation successful: RDP is enabled and 'Everyone' is in the Remote Desktop Users group." -Level "INFO"
            $validationSucceeded = $true
            $completedSteps++
        }
        else {
            Write-Log "Validation attempt $($retryCount + 1) failed: RDP or group membership is not configured correctly." -Level "ERROR"
        }
        $retryCount++
    }

    if (-not $validationSucceeded) {
        Write-Log "Validation failed after $maxRetries attempts: RDP or group membership was not configured correctly." -Level "ERROR"
    }

    # Step 6: Summary report
    Write-Host "Summary: $completedSteps out of $totalSteps steps completed successfully." -ForegroundColor Cyan
    if ($completedSteps -eq $totalSteps) {
        Write-Host "RDP was enabled and 'Everyone' was added to the Remote Desktop Users group successfully." -ForegroundColor Green
    }
    else {
        Write-Host "There were issues during the configuration. Please check the log for details." -ForegroundColor Red
    }

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