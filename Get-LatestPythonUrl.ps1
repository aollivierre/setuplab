# Function to fetch the latest Python installer URL dynamically
function Get-LatestPythonUrl {
    [CmdletBinding()]
    param()
    
    try {
        Write-SetupLog "Fetching latest Python version..." -Level Debug
        
        # Python.org API for latest releases
        $pythonApiUrl = "https://www.python.org/api/v2/downloads/release/?is_published=true&pre_release=false&page_size=1"
        
        $response = Invoke-RestMethod -Uri $pythonApiUrl -ErrorAction Stop
        
        if ($response.results -and $response.results.Count -gt 0) {
            $latestRelease = $response.results[0]
            $version = $latestRelease.name -replace 'Python\s+', ''
            
            Write-SetupLog "Latest Python version found: $version" -Level Debug
            
            # Find Windows x64 installer
            $windowsInstaller = $latestRelease.files | Where-Object {
                $_.os -eq 'Windows' -and 
                $_.description -match 'Windows installer \(64-bit\)' -and
                $_.url -match '\.exe$'
            } | Select-Object -First 1
            
            if ($windowsInstaller) {
                Write-SetupLog "Found Windows x64 installer: $($windowsInstaller.url)" -Level Debug
                return $windowsInstaller.url
            }
        }
        
        # Fallback to direct URL pattern if API fails
        Write-SetupLog "API method failed, trying direct URL pattern..." -Level Warning
        
        # Try to get latest version from Python.org downloads page
        $downloadsPage = Invoke-WebRequest -Uri "https://www.python.org/downloads/" -ErrorAction Stop
        
        if ($downloadsPage.Content -match 'href="(/ftp/python/[\d\.]+/python-[\d\.]+-amd64\.exe)"') {
            $installerPath = $Matches[1]
            $downloadUrl = "https://www.python.org$installerPath"
            Write-SetupLog "Found Python installer via page scraping: $downloadUrl" -Level Debug
            return $downloadUrl
        }
        
        # Final fallback - return a known good version
        Write-SetupLog "All dynamic methods failed, using fallback URL" -Level Warning
        return "https://www.python.org/ftp/python/3.13.1/python-3.13.1-amd64.exe"
        
    } catch {
        Write-SetupLog "Error fetching latest Python URL: $_" -Level Error
        # Return a known good fallback URL
        return "https://www.python.org/ftp/python/3.13.1/python-3.13.1-amd64.exe"
    }
}

# Export the function if running as a module
if ($MyInvocation.InvocationName -ne '.') {
    Export-ModuleMember -Function Get-LatestPythonUrl
}