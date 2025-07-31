# Script to update SetupLabCore.psm1 to use enhanced logging

$coreModulePath = "C:\code\setuplab\SetupLabCore.psm1"
$content = Get-Content $coreModulePath -Raw

# Add import for the new logging module at the beginning
$importStatement = @'
# Import enhanced logging module
$loggingModulePath = Join-Path $PSScriptRoot "SetupLabLogging.psm1"
if (Test-Path $loggingModulePath) {
    Import-Module $loggingModulePath -Force
    Initialize-SetupLog -LogName "SetupLab"
}

'@

# Insert after the #region Module Variables section
$insertPoint = $content.IndexOf("#endregion", $content.IndexOf("#region Module Variables"))
if ($insertPoint -gt 0) {
    $insertPoint = $content.IndexOf("`n", $insertPoint) + 1
    $newContent = $content.Insert($insertPoint, "`n$importStatement")
    
    # Update Write-SetupLog function to use Write-SetupLogEx
    $updatedLogFunction = @'
function Write-SetupLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info',
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile = "SetupLab_$((Get-Date).ToString('yyyyMMdd')).log"
    )
    
    # Use enhanced logging if available
    if (Get-Command Write-SetupLogEx -ErrorAction SilentlyContinue) {
        Write-SetupLogEx -Message $Message -Level $Level
    }
    else {
        # Fallback to original implementation
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = if ($Message) { "[$timestamp] [$Level] $Message" } else { "" }
        $logFilePath = Join-Path $script:LogPath $LogFile
        
        # Write to log file with retry logic for concurrent access
        $maxRetries = 3
        $retryCount = 0
        
        while ($retryCount -lt $maxRetries) {
            try {
                Add-Content -Path $logFilePath -Value $logMessage -Force
                break
            }
            catch {
                $retryCount++
                if ($retryCount -eq $maxRetries) {
                    # If all retries fail, try alternative logging method
                    try {
                        Out-File -FilePath $logFilePath -InputObject $logMessage -Append -Force
                    }
                    catch {
                        # Final fallback - just output to console
                        Write-Host "[LOG ERROR] $logMessage" -ForegroundColor Red
                    }
                }
                else {
                    Start-Sleep -Milliseconds (100 * $retryCount)
                }
            }
        }
        
        # Write to console with color
        $color = switch ($Level) {
            'Success' { 'Green' }
            'Warning' { 'Yellow' }
            'Error'   { 'Red' }
            'Debug'   { 'Gray' }
            default   { 'White' }
        }
        
        if ($Message) {
            Write-Host $logMessage -ForegroundColor $color
        } else {
            Write-Host ""
        }
    }
}
'@

    # Replace the Write-SetupLog function
    $pattern = 'function Write-SetupLog\s*{[\s\S]*?^}'
    $newContent = $newContent -replace $pattern, $updatedLogFunction.Trim()
    
    # Save the updated content
    Set-Content -Path $coreModulePath -Value $newContent -Force
    
    Write-Host "Successfully updated SetupLabCore.psm1 with enhanced logging integration" -ForegroundColor Green
}
else {
    Write-Host "Could not find insertion point in SetupLabCore.psm1" -ForegroundColor Red
}