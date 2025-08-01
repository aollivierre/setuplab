# Trace Claude CLI installation error in detail
param(
    [string]$RemoteComputer = "198.18.1.157",
    [string]$Username = "xyz\administrator", 
    [string]$Password = "Default1234"
)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

Write-Host "Tracing Claude CLI error on $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $credential -ErrorAction Stop
    
    # First, let's see what the actual error is by running the script with transcript
    $result = Invoke-Command -Session $session -ScriptBlock {
        $transcriptPath = "$env:TEMP\claude-cli-trace.txt"
        Start-Transcript -Path $transcriptPath -Force
        
        try {
            # Download the latest install-claude-cli.ps1
            $scriptUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/main/install-claude-cli.ps1"
            $scriptPath = "$env:TEMP\install-claude-cli-test.ps1"
            
            Write-Host "Downloading install-claude-cli.ps1..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
            
            Write-Host "Script size: $(Get-Item $scriptPath).Length bytes" -ForegroundColor Gray
            
            # Set verbose preference to capture more details
            $VerbosePreference = "Continue"
            $DebugPreference = "Continue"
            
            Write-Host "`nExecuting install-claude-cli.ps1 with detailed tracing..." -ForegroundColor Cyan
            
            # Execute with error details
            & $scriptPath -ErrorAction Stop
            
        } catch {
            Write-Host "`nERROR DETAILS:" -ForegroundColor Red
            Write-Host "Message: $_" -ForegroundColor Red
            Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            Write-Host "Target Object: $($_.TargetObject)" -ForegroundColor Red
            Write-Host "Category Info: $($_.CategoryInfo)" -ForegroundColor Red
            Write-Host "Invocation Info: $($_.InvocationInfo.Line)" -ForegroundColor Red
            Write-Host "Script Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
            
            # Try to find the exact line causing the issue
            if ($_.InvocationInfo.ScriptLineNumber) {
                Write-Host "`nError at line $($_.InvocationInfo.ScriptLineNumber):" -ForegroundColor Yellow
                $scriptContent = Get-Content $scriptPath
                $errorLine = $_.InvocationInfo.ScriptLineNumber - 1
                if ($errorLine -ge 0 -and $errorLine -lt $scriptContent.Count) {
                    Write-Host ">>> $($scriptContent[$errorLine])" -ForegroundColor Magenta
                }
            }
        } finally {
            Stop-Transcript
        }
        
        # Return the transcript
        Get-Content $transcriptPath -Raw
    }
    
    Write-Host "`nTranscript Output:" -ForegroundColor Cyan
    Write-Host $result
    
    # Save to local file
    $result | Out-File -FilePath "C:\code\setuplab\claude-cli-error-trace.txt" -Encoding UTF8
    Write-Host "`nFull trace saved to: C:\code\setuplab\claude-cli-error-trace.txt" -ForegroundColor Green
    
    Remove-PSSession -Session $session
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}