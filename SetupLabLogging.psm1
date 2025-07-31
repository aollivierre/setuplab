#Requires -Version 5.1
<#
.SYNOPSIS
    Enhanced logging module for SetupLab with detailed tracking
.DESCRIPTION
    Provides comprehensive logging with line numbers, function names, and timestamps
    Logs are written to C:\ProgramData\SetupLab\Logs
#>

#region Module Variables
$script:LogBasePath = "C:\ProgramData\SetupLab\Logs"
$script:CurrentLogFile = $null
$script:LogMutex = New-Object System.Threading.Mutex($false, "SetupLabLogMutex")
#endregion

#region Initialization
# Ensure log directory exists
if (-not (Test-Path $script:LogBasePath)) {
    try {
        New-Item -ItemType Directory -Path $script:LogBasePath -Force | Out-Null
    }
    catch {
        # Fallback to user temp if ProgramData is not accessible
        $script:LogBasePath = Join-Path $env:TEMP "SetupLab\Logs"
        New-Item -ItemType Directory -Path $script:LogBasePath -Force | Out-Null
    }
}
#endregion

#region Core Logging Functions
function Initialize-SetupLog {
    <#
    .SYNOPSIS
        Initializes a new log file for the current session
    .DESCRIPTION
        Creates a new timestamped log file and sets it as the current log
    .PARAMETER LogName
        Optional custom log name prefix
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$LogName = "SetupLab"
    )
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFileName = "${LogName}_${timestamp}.log"
    $script:CurrentLogFile = Join-Path $script:LogBasePath $logFileName
    
    # Write initial header
    $header = @"
================================================================================
SetupLab Installation Log
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Machine: $env:COMPUTERNAME
User: $env:USERNAME
Domain: $env:USERDOMAIN
PowerShell Version: $($PSVersionTable.PSVersion)
================================================================================

"@
    
    Add-Content -Path $script:CurrentLogFile -Value $header -Force
    
    return $script:CurrentLogFile
}

function Write-SetupLogEx {
    <#
    .SYNOPSIS
        Enhanced logging function with detailed context information
    .DESCRIPTION
        Writes log entries with timestamp, level, function name, line number, and message
    .PARAMETER Message
        The message to log
    .PARAMETER Level
        Log level (Info, Success, Warning, Error, Debug, Verbose)
    .PARAMETER CallerInfo
        Automatically populated with caller information
    .PARAMETER NoConsole
        Suppress console output
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug', 'Verbose')]
        [string]$Level = 'Info',
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.InvocationInfo]$CallerInfo = (Get-PSCallStack)[1].InvocationInfo,
        
        [Parameter(Mandatory = $false)]
        [switch]$NoConsole
    )
    
    # Initialize log if not already done
    if (-not $script:CurrentLogFile) {
        Initialize-SetupLog | Out-Null
    }
    
    # Extract caller information
    $functionName = if ($CallerInfo.MyCommand) { $CallerInfo.MyCommand.Name } else { '<Script>' }
    $lineNumber = $CallerInfo.ScriptLineNumber
    $scriptName = if ($CallerInfo.ScriptName) { Split-Path -Leaf $CallerInfo.ScriptName } else { '<Unknown>' }
    
    # Format the log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[{0}] [{1,-7}] [{2}:{3}:{4,-4}] {5}" -f $timestamp, $Level.ToUpper(), $scriptName, $functionName, $lineNumber, $Message
    
    # Thread-safe file writing
    $acquired = $false
    try {
        $acquired = $script:LogMutex.WaitOne(5000)
        if ($acquired) {
            Add-Content -Path $script:CurrentLogFile -Value $logEntry -Force
        }
        else {
            # If we can't get mutex, at least write to console
            Write-Host "[MUTEX TIMEOUT] $logEntry" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "[LOG ERROR] Failed to write: $_" -ForegroundColor Red
        Write-Host "[LOG ENTRY] $logEntry" -ForegroundColor Gray
    }
    finally {
        if ($acquired) {
            $script:LogMutex.ReleaseMutex()
        }
    }
    
    # Console output
    if (-not $NoConsole) {
        $color = switch ($Level) {
            'Success' { 'Green' }
            'Warning' { 'Yellow' }
            'Error'   { 'Red' }
            'Debug'   { 'Gray' }
            'Verbose' { 'Cyan' }
            default   { 'White' }
        }
        
        # Simplified console output
        $consoleMessage = "[{0}] [{1,-7}] {2}" -f (Get-Date -Format "HH:mm:ss"), $Level.ToUpper(), $Message
        Write-Host $consoleMessage -ForegroundColor $color
    }
}

function Write-SetupProgress {
    <#
    .SYNOPSIS
        Writes a progress entry with visual separator
    .DESCRIPTION
        Creates visually distinct progress markers in the log
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Activity,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Start', 'End', 'Section')]
        [string]$Type = 'Section'
    )
    
    $separator = switch ($Type) {
        'Start'   { "=" * 80 }
        'End'     { "=" * 80 }
        'Section' { "-" * 60 }
    }
    
    Write-SetupLogEx "" -NoConsole:$false
    Write-SetupLogEx $separator -NoConsole:$false
    Write-SetupLogEx $Activity -Level Info
    if ($Type -eq 'Start') {
        Write-SetupLogEx $separator -NoConsole:$false
    }
    Write-SetupLogEx "" -NoConsole:$false
}

function Write-SetupError {
    <#
    .SYNOPSIS
        Writes detailed error information to the log
    .DESCRIPTION
        Captures full error details including stack trace
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [Parameter(Mandatory = $false)]
        [string]$Context = ""
    )
    
    Write-SetupLogEx "ERROR: $Context" -Level Error
    Write-SetupLogEx "Exception: $($ErrorRecord.Exception.Message)" -Level Error
    Write-SetupLogEx "Category: $($ErrorRecord.CategoryInfo.Category)" -Level Error
    Write-SetupLogEx "Target: $($ErrorRecord.TargetObject)" -Level Error
    Write-SetupLogEx "Script StackTrace:" -Level Error
    
    $stackTrace = $ErrorRecord.ScriptStackTrace -split "`n"
    foreach ($line in $stackTrace) {
        if ($line.Trim()) {
            Write-SetupLogEx "  $line" -Level Error -NoConsole
        }
    }
}

function Get-SetupLogPath {
    <#
    .SYNOPSIS
        Returns the current log file path
    #>
    [CmdletBinding()]
    param()
    
    if (-not $script:CurrentLogFile) {
        Initialize-SetupLog | Out-Null
    }
    
    return $script:CurrentLogFile
}

function Write-SetupSummary {
    <#
    .SYNOPSIS
        Writes a summary section to the log
    .DESCRIPTION
        Creates a formatted summary with statistics
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Summary
    )
    
    Write-SetupProgress -Activity "Installation Summary" -Type End
    
    foreach ($key in $Summary.Keys | Sort-Object) {
        $value = $Summary[$key]
        Write-SetupLogEx ("  {0,-30}: {1}" -f $key, $value) -Level Info
    }
    
    Write-SetupLogEx "" -NoConsole:$false
}
#endregion

#region Utility Functions
function Start-SetupLogSection {
    <#
    .SYNOPSIS
        Starts a new logical section in the log
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SectionName
    )
    
    Write-SetupProgress -Activity $SectionName -Type Start
}

function End-SetupLogSection {
    <#
    .SYNOPSIS
        Ends a logical section in the log
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SectionName,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Success', 'Warning', 'Error')]
        [string]$Result = 'Success'
    )
    
    $resultMessage = "$SectionName - Completed with status: $Result"
    Write-SetupLogEx $resultMessage -Level $Result
    Write-SetupLogEx ("-" * 60) -NoConsole:$false
}

function Write-SetupDebugInfo {
    <#
    .SYNOPSIS
        Writes debug information when verbose logging is enabled
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Data
    )
    
    if ($VerbosePreference -eq 'Continue' -or $DebugPreference -eq 'Continue') {
        Write-SetupLogEx $Message -Level Debug
        
        if ($Data) {
            foreach ($key in $Data.Keys) {
                Write-SetupLogEx "  $key = $($Data[$key])" -Level Debug -NoConsole
            }
        }
    }
}
#endregion

#region Export
Export-ModuleMember -Function @(
    'Initialize-SetupLog',
    'Write-SetupLogEx',
    'Write-SetupProgress',
    'Write-SetupError',
    'Get-SetupLogPath',
    'Write-SetupSummary',
    'Start-SetupLogSection',
    'End-SetupLogSection',
    'Write-SetupDebugInfo'
)
#endregion