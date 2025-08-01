# Download SetupLabCore.psm1 to examine locally
$url = "https://raw.githubusercontent.com/aollivierre/setuplab/main/SetupLabCore.psm1"
$outFile = "SetupLabCore.psm1"

Write-Host "Downloading SetupLabCore.psm1..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing
Write-Host "Downloaded to: $outFile" -ForegroundColor Green