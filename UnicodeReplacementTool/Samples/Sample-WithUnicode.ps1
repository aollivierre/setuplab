# Sample PowerShell script with Unicode characters that break PowerShell 5.1
# This file is intentionally created with Unicode characters for testing

Write-Host "Starting deployment process... 🚀" -ForegroundColor Green

# Configuration settings 🔧
$config = @{
    Status = "✓ Ready"
    Error = "✗ Failed"
    Warning = "⚠ Check logs"
    Info = "ℹ Information"
}

# File operations
Write-Host "📁 Creating folder structure..."
Write-Host "📄 Processing files..."

# Status indicators
$success = $true
if ($success) {
    Write-Host "✅ Operation completed successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Operation failed!" -ForegroundColor Red
}

# Progress indicators
Write-Host "Progress: 25% → 50% → 75% → 100%"

# Math operations
$result = 100
Write-Host "Result: $result ± 5"
Write-Host "Temperature: 25°C"

# Currency
Write-Host "Cost: €100 or £85"

# Quotes and special characters
Write-Host "He said "Hello" and she replied 'Hi'"
Write-Host "Loading…"

# Emojis in comments and strings
# 👍 This function works great!
# 👎 This needs improvement
# 💡 Idea: Add more features

function Test-Unicode {
    # 🔍 Search for items
    # 🔒 Lock the resource
    # 🔓 Unlock when done
    
    Write-Host "🐛 Found a bug!"
    Write-Host "🔥 Critical issue!"
    Write-Host "🏁 Finished!"
}

# Mathematical symbols
$pi = "π ≈ 3.14159"
$sum = "Σ(1 to n) = n(n+1)/2"

# Status with symbols
$statuses = @(
    "• Item 1",
    "◦ Sub-item",
    "▶ Play",
    "◀ Previous",
    "■ Stop",
    "□ Unchecked"
)

# Copyright and trademark
Write-Host "© 2024 Company™ - All rights reserved®"

# Fractions
Write-Host "Progress: ½ complete, ¼ remaining"

# Greek letters
Write-Host "α beta γ delta testing"

# Comparison operators (that look similar but are Unicode)
if ($value –eq 5) {  # This is an en-dash, not a regular dash!
    Write-Host "Value equals 5"
}