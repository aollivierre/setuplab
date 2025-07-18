#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Renames the computer to WinUpgrade3
.DESCRIPTION
    This script renames the computer and optionally restarts it
.EXAMPLE
    .\Rename-Computer.ps1
#>

[CmdletBinding()]
param()

#region Script Configuration
$NewComputerName = "WinUpgrade3"
#endregion

#region Main Script
try {
    Write-Host "Starting computer rename process..." -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Gray
    
    # Get current computer name
    $CurrentName = $env:COMPUTERNAME
    Write-Host "`nCurrent computer name: $CurrentName" -ForegroundColor Yellow
    Write-Host "New computer name: $NewComputerName" -ForegroundColor Green
    
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
catch {
    Write-Host "`nError occurred: $_" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
#endregion