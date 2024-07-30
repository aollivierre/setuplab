# Path to your secrets file
$secretsPath = "$psscriptroot\secrets.psd1"

# Import the secrets file
$secrets = Import-PowerShellDataFile -Path $secretsPath

# Retrieve the Bitly API token from the secrets file
$bitlyToken = $secrets.BitlyToken

# The URL you want to shorten
$longUrl = "https://raw.githubusercontent.com/aollivierre/setuplab/main/setuplab.ps1"

# The Bitly API endpoint for shortening URLs
$bitlyApiUrl = "https://api-ssl.bitly.com/v4/shorten"

# Prepare the request headers
$headers = @{
    "Authorization" = "Bearer $bitlyToken"
    "Content-Type"  = "application/json"
}

# Prepare the request body
$body = @{
    "long_url" = $longUrl
} | ConvertTo-Json

# Make the request to the Bitly API
$response = Invoke-RestMethod -Uri $bitlyApiUrl -Method POST -Headers $headers -Body $body

# Output the shortened URL
$shortUrl = $response.link
Write-Host "Shortened URL: $shortUrl"