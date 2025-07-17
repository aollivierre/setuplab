# PowerShell Script Execution from URLs Guide

This guide explains different methods of executing PowerShell scripts from URLs, with a focus on security implications and best practices.

## Table of Contents

- [PowerShell Script Execution from URLs Guide](#powershell-script-execution-from-urls-guide)
  - [Table of Contents](#table-of-contents)
  - [Example Script](#example-script)
  - [Method 1: Direct Memory Execution (Invoke-Expression)](#method-1-direct-memory-execution-invoke-expression)
    - [Characteristics of Memory Execution](#characteristics-of-memory-execution)
  - [Method 2: Download and Execute (Safer Approach)](#method-2-download-and-execute-safer-approach)
    - [Characteristics of Download Method](#characteristics-of-download-method)
  - [Method 3: Using Invoke-WebRequest with Direct Execution](#method-3-using-invoke-webrequest-with-direct-execution)
    - [Characteristics of Invoke-WebRequest](#characteristics-of-invoke-webrequest)
  - [Security Considerations](#security-considerations)
    - [When Using Raw GitHub URLs](#when-using-raw-github-urls)
    - [General Security Best Practices](#general-security-best-practices)
  - [Execution Policy Notes](#execution-policy-notes)
  - [Troubleshooting Tips](#troubleshooting-tips)
    - [Common Issues](#common-issues)
  - [Example Usage for Our Script](#example-usage-for-our-script)
    - [Memory-Only Execution](#memory-only-execution)
    - [Download and Verify](#download-and-verify)
  - [Additional Resources](#additional-resources)

## Example Script

Our example uses a network configuration script located at:

```powershell
https://raw.githubusercontent.com/aollivierre/HyperV/refs/heads/main/2-Create-HyperV_VM/Latest/Prepare%20Server%20Core%20Domain%20Controller/1-Set-Static-IPV4-from-DHCP-Configs.ps1
```

## Method 1: Direct Memory Execution (Invoke-Expression)

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('YOUR_SCRIPT_URL'))
```

### Characteristics of Memory Execution

- Script runs directly in memory
- No file is saved to disk
- Faster execution
- Harder to inspect before execution
- Memory-only footprint
- Good for one-time execution
- Less secure as script content can't be easily verified before execution

## Method 2: Download and Execute (Safer Approach)

```powershell
$scriptUrl = 'YOUR_SCRIPT_URL'
$outputPath = "$env:TEMP\Script.ps1"
Invoke-WebRequest -Uri $scriptUrl -OutFile $outputPath
Get-Content $outputPath | Write-Host
Read-Host "Press Enter to execute the script"
Set-ExecutionPolicy Bypass -Scope Process -Force
& $outputPath
```

### Characteristics of Download Method

- Script is downloaded to disk first
- Can be inspected before execution
- Creates a local copy for reference
- More control over the execution process
- Better for security auditing
- Allows for script verification before execution
- Required for scripts using `$PSScriptRoot` or similar automatic variables that depend on file paths
- Better for scripts that need to reference their own location or relative paths

## Method 3: Using Invoke-WebRequest with Direct Execution

```powershell
$scriptUrl = 'YOUR_SCRIPT_URL'
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing | Select-Object -ExpandProperty Content | Invoke-Expression
```

### Characteristics of Invoke-WebRequest

- Modern alternative to WebClient
- Better handling of special characters in URLs
- Supports more authentication methods
- More features like progress tracking
- Still runs in memory
- More robust error handling

## Security Considerations

### When Using Raw GitHub URLs

1. Always use the `raw.githubusercontent.com` domain
2. Ensure you're using the correct branch (e.g., `main`, `master`)
3. URL format should be: `https://raw.githubusercontent.com/USER/REPO/BRANCH/PATH/TO/SCRIPT`

### General Security Best Practices

1. **Always verify the source** of the script
2. Use **HTTPS** URLs only
3. Consider using **script signing** for production environments
4. Implement **hash verification** for critical scripts
5. Use `-UseBasicParsing` with `Invoke-WebRequest` for better compatibility
6. Consider using `-ExecutionPolicy` scoped to `Process` only
7. Avoid storing credentials in scripts
8. Review scripts before execution when possible

## Execution Policy Notes

```powershell
# Temporary bypass for current process only
Set-ExecutionPolicy Bypass -Scope Process -Force

# More restrictive alternatives
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
Set-ExecutionPolicy AllSigned -Scope CurrentUser
```

## Troubleshooting Tips

### Common Issues

1. **SSL/TLS Errors**: Ensure you're using TLS 1.2 or higher

   ```powershell
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   ```

2. **URL Encoding Issues**: Use `[System.Web.HttpUtility]::UrlEncode()` for complex URLs

3. **Proxy Considerations**: Use `-Proxy` parameter with `Invoke-WebRequest` if needed

4. **Timeout Issues**: Adjust timeout settings for large scripts

   ```powershell
   $webClient.Timeout = 30000  # 30 seconds
   ```

## Example Usage for Our Script

### Memory-Only Execution

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/aollivierre/HyperV/refs/heads/main/2-Create-HyperV_VM/Latest/Prepare%20Server%20Core%20Domain%20Controller/1-Set-Static-IPV4-from-DHCP-Configs.ps1'))
```

### Download and Verify

```powershell
$scriptUrl = 'https://raw.githubusercontent.com/aollivierre/HyperV/refs/heads/main/2-Create-HyperV_VM/Latest/Prepare%20Server%20Core%20Domain%20Controller/1-Set-Static-IPV4-from-DHCP-Configs.ps1'
$outputPath = "$env:TEMP\Set-Static-IPV4.ps1"
Invoke-WebRequest -Uri $scriptUrl -OutFile $outputPath
Get-Content $outputPath | Write-Host
Read-Host "Press Enter to execute the script"
Set-ExecutionPolicy Bypass -Scope Process -Force
& $outputPath
```

## Additional Resources

- [PowerShell Security Documentation](https://docs.microsoft.com/en-us/powershell/scripting/learn/security-features)
- [About Execution Policies](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)
- [Invoke-WebRequest Documentation](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest)
