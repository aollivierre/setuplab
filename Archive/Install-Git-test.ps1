# Define the URL for the GitHub API
$apiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"

# Define the headers to mimic a browser request
$headers = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"
}

# Fetch the latest release information from the GitHub API
$response = Invoke-RestMethod -Uri $apiUrl -Headers $headers

# Extract the URL for the 64-bit installer from the assets
$installerUrl = $response.assets | Where-Object { $_.name -like "*64-bit.exe" } | Select-Object -ExpandProperty browser_download_url

# Define the local path where the installer will be saved
$installerPath = "$PSScriptRoot\Git-Installer.exe"

# Download the installer
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath

Write-Host "Downloaded the latest Git installer to $installerPath" -ForegroundColor Green

# Optionally, you can run the installer after downloading
# Start-Process -FilePath $installerPath -ArgumentList "/SILENT" -Wait
