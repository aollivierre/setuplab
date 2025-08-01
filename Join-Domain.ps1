#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Joins a computer to the xyz.local domain
.DESCRIPTION
    This script joins the computer to xyz.local domain using specified credentials
    and tests the domain connection after joining
.EXAMPLE
    .\Join-Domain.ps1
#>

[CmdletBinding()]
param()

#region Script Configuration
$DomainName = "xyz.local"
$DomainUser = "xyz\administrator"
$DomainPassword = "Default1234"
#endregion

#region Main Script
try {
    Write-Host "Starting domain join process..." -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Gray
    
    # Convert password to secure string
    $SecurePassword = ConvertTo-SecureString $DomainPassword -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential($DomainUser, $SecurePassword)
    
    # Check current domain status
    Write-Host "`nChecking current domain status..." -ForegroundColor Yellow
    $ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
    
    if ($ComputerSystem.Domain -eq $DomainName) {
        Write-Host "Computer is already joined to $DomainName" -ForegroundColor Green
        $AlreadyJoined = $true
    }
    else {
        Write-Host "Current domain/workgroup: $($ComputerSystem.Domain)" -ForegroundColor White
        Write-Host "Target domain: $DomainName" -ForegroundColor White
        $AlreadyJoined = $false
    }
    
    if (-not $AlreadyJoined) {
        # Test domain controller connectivity first
        Write-Host "`nTesting domain controller connectivity..." -ForegroundColor Yellow
        $DomainController = $null
        
        try {
            $DomainController = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain(
                [System.DirectoryServices.ActiveDirectory.DirectoryContext]::new(
                    [System.DirectoryServices.ActiveDirectory.DirectoryContextType]::Domain,
                    $DomainName,
                    $Credential.UserName,
                    $Credential.GetNetworkCredential().Password
                )
            ).FindDomainController().Name
            
            Write-Host "Successfully contacted domain controller: $DomainController" -ForegroundColor Green
        }
        catch {
            Write-Warning "Unable to contact domain controller. Please check:"
            Write-Warning "- Network connectivity to domain"
            Write-Warning "- DNS settings (should point to domain controller)"
            Write-Warning "- Firewall settings"
            throw "Domain controller connectivity test failed: $_"
        }
        
        # Join the domain
        Write-Host "`nJoining computer to domain..." -ForegroundColor Yellow
        Add-Computer -DomainName $DomainName -Credential $Credential -Force -ErrorAction Stop
        
        Write-Host "Successfully joined to domain $DomainName" -ForegroundColor Green
        Write-Host "`nA restart is required to complete the domain join." -ForegroundColor Yellow
        
        $Restart = Read-Host "Do you want to restart now? (Y/N)"
        if ($Restart -eq 'Y' -or $Restart -eq 'y') {
            Write-Host "Restarting computer in 10 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            Restart-Computer -Force
        }
        else {
            Write-Host "Please restart the computer manually to complete the domain join." -ForegroundColor Yellow
        }
    }
    else {
        # Test domain connectivity
        Write-Host "`nTesting domain connectivity..." -ForegroundColor Yellow
        
        # Test 1: Domain Controller reachability
        Write-Host "Test 1: Domain Controller connectivity" -ForegroundColor White
        try {
            $DC = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers[0]
            Write-Host "  Primary DC: $($DC.Name)" -ForegroundColor Green
            
            if (Test-Connection -ComputerName $DC.Name -Count 2 -Quiet) {
                Write-Host "  DC is reachable" -ForegroundColor Green
            }
            else {
                Write-Host "  DC is not reachable" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "  Unable to query domain controller" -ForegroundColor Red
        }
        
        # Test 2: Domain authentication
        Write-Host "`nTest 2: Domain authentication" -ForegroundColor White
        try {
            $Domain = [ADSI]"LDAP://$DomainName"
            $Searcher = New-Object System.DirectoryServices.DirectorySearcher($Domain)
            $Searcher.SearchRoot = $Domain
            $Searcher.Filter = "(objectClass=domain)"
            $Result = $Searcher.FindOne()
            
            if ($null -ne $Result) {
                Write-Host "  Successfully authenticated to domain" -ForegroundColor Green
            }
            else {
                Write-Host "  Authentication failed" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "  Authentication test failed: $_" -ForegroundColor Red
        }
        
        # Test 3: Group Policy
        Write-Host "`nTest 3: Group Policy status" -ForegroundColor White
        try {
            $GPResult = gpresult /r /scope computer 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Group Policy is being applied" -ForegroundColor Green
            }
            else {
                Write-Host "  Group Policy application issues detected" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  Unable to check Group Policy status" -ForegroundColor Yellow
        }
        
        Write-Host "`nDomain connectivity tests completed." -ForegroundColor Cyan
    }
}
catch {
    Write-Host "`nError occurred: $_" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
#endregion