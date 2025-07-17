**PowerShell 5.1 vs 7 Compatibility Issues:**
<?xml version="1.0" encoding="UTF-8"?>
<PowerShellCodingStandards version="1.0">
  <!-- CRITICAL STANDARDS -->
  <!-- Variables: Never place colons after variable names ($var: value), use proper spacing or ${var}: -->
  <!-- Operators: Use -and, -or, -not, -eq, -ne, -gt, -lt, -ge, -le; NEVER use &&, ||, !, ==, !=, >, <, >=, <= -->
  <!-- Null: Place $null on LEFT side of comparisons: ($null -eq $var) NOT ($var -eq $null) -->
  <!-- Conditionals: Use ($result = if ($cond) { $true } else { $false }) NOT ternary operators -->
  <!-- Special Ops: NEVER use PowerShell 7+ operators (??, ?.) in PowerShell 5.1 code -->
  <!-- Params: Never use reserved parameter names (Verbose, Debug, ErrorAction, etc.) -->
  <!-- Variables: Never reassign automatic variables like $PSScriptRoot or $MyInvocation -->
  <!-- Strings: Use ASCII-compatible chars, not Unicode symbols like ? or ? -->
  <!-- String Multiplication: Use parentheses for string multiplication in concatenation: ("=" * 60) NOT "="*60 -->
  <!-- Modules: Place all Export-ModuleMember statements ONLY in the main .psm1 file -->
  <!-- Functions: Always include complete comment-based help for all functions -->
  <!-- Organization: Use #region/#endregion markers for logical code sections -->
  <!-- Comments: Include detailed comments for initialization, logic, loops, error handling -->
  <!-- CRITICAL: NEVER USE PESTER FOR TESTING UNDER ANY CIRCUMSTANCES! -->
  <!-- Use script-based testing with functions and try/catch blocks instead -->
  <!-- If lint errors persist after a few attempts, do not continue trying to fix them. Instead, inform the human user about the persistent errors and request manual intervention. -->
  
  <!-- COMMAND LINE EXECUTION BEST PRACTICES -->
  <!-- PowerShell -Command: Prone to escaping issues with $, {}, quotes, <, > characters -->
  <!-- PowerShell -File: Much more reliable for complex scripts - write to .ps1 file first -->
  <!-- Unix Tools: Prefer grep, awk, sed for text processing - more predictable and composable -->
  <!-- Mixed Approach: Use PowerShell for Windows-specific tasks (registry, WMI), Unix tools for general processing -->
  <!-- Complex Commands: For multi-line or complex PowerShell, ALWAYS use script files instead of -Command -->
  <!-- Escaping: When using -Command, be extremely careful with special characters and quotes -->
  <!-- Path Handling: Use forward slashes in Git Bash, backslashes in PowerShell scripts -->
</PowerShellCodingStandards>