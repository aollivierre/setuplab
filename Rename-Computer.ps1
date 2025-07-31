#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Prompts for and renames the computer to a user-specified name
.DESCRIPTION
    This script prompts the user for a new computer name, validates it,
    renames the computer and optionally restarts it
.EXAMPLE
    .\Rename-Computer.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$NewComputerName,
    
    [Parameter(Mandatory = $false)]
    [switch]$NoPrompt,
    
    [Parameter(Mandatory = $false)]
    [switch]$NoRestart
)

#region Script Configuration
# Prompt user for new computer name
#endregion

#region Main Script
try {
    Write-Host "Starting computer rename process..." -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Gray
    
    # Get current computer name
    $CurrentName = $env:COMPUTERNAME
    Write-Host "`nCurrent computer name: $CurrentName" -ForegroundColor Yellow
    
    # Get computer name (either from parameter or prompt)
    if (-not $NewComputerName -and -not $NoPrompt) {
        # Prompt for new computer name
        Write-Host "`nPlease enter the new computer name (15 characters max, alphanumeric and hyphens only):" -ForegroundColor Cyan
        $NewComputerName = Read-Host "New computer name"
    }
    
    # Validate computer name
    if ([string]::IsNullOrWhiteSpace($NewComputerName)) {
        Write-Host "`nNo computer name provided. Exiting..." -ForegroundColor Yellow
        exit 0
    }
    
    # Validate length (NetBIOS name limit is 15 characters)
    if ($NewComputerName.Length -gt 15) {
        Write-Host "`nError: Computer name cannot exceed 15 characters." -ForegroundColor Red
        exit 1
    }
    
    # Validate characters (alphanumeric and hyphens only, cannot start with hyphen)
    if ($NewComputerName -notmatch '^[a-zA-Z0-9][a-zA-Z0-9-]*$') {
        Write-Host "`nError: Computer name can only contain letters, numbers, and hyphens (cannot start with hyphen)." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "`nNew computer name: $NewComputerName" -ForegroundColor Green
    
    if ($CurrentName -eq $NewComputerName) {
        Write-Host "`nComputer is already named $NewComputerName" -ForegroundColor Green
        exit 0
    }
    
    # Check if domain joined
    $ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $IsDomainJoined = $ComputerSystem.PartOfDomain
    
    Write-Host "`nRenaming computer..." -ForegroundColor Yellow
    
    if ($IsDomainJoined) {
        Write-Host "Computer is domain-joined. Domain credentials required." -ForegroundColor Yellow
        
        # Domain credentials
        $DomainUser = "abc\administrator"
        $DomainPassword = "Default1234"
        $SecurePassword = ConvertTo-SecureString $DomainPassword -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential($DomainUser, $SecurePassword)
        
        Rename-Computer -NewName $NewComputerName -DomainCredential $Credential -Force -ErrorAction Stop
    }
    else {
        Rename-Computer -NewName $NewComputerName -Force -ErrorAction Stop
    }
    
    Write-Host "`nComputer successfully renamed to $NewComputerName" -ForegroundColor Green
    Write-Host "A restart is required for the changes to take effect." -ForegroundColor Yellow
    
    if (-not $NoRestart -and -not $NoPrompt) {
        $Restart = Read-Host "`nDo you want to restart now? (Y/N)"
        if ($Restart -eq 'Y' -or $Restart -eq 'y') {
            Write-Host "Restarting computer in 10 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            Restart-Computer -Force
        }
        else {
            Write-Host "Please restart the computer manually to complete the rename." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Please restart the computer manually to complete the rename." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`nError occurred: $_" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
#endregion