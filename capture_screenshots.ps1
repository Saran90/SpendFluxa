# PowerShell Script to Generate SpendFlux Screenshots
# This script creates HTML-based screenshots and converts them to PNG

param(
    [string]$OutputDir = "store_assets/screenshots/phone",
    [int]$Width = 1080,
    [int]$Height = 1920
)

Write-Host "🎨 SpendFlux Screenshot Generator" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "✓ Created output directory: $OutputDir" -ForegroundColor Green
}

# Check if Chrome/Edge is available for headless capture
$browsers = @(
    @{Name="Chrome"; Path="chrome.exe"; Args="--headless --disable-gpu --screenshot"},
    @{Name="Edge"; Path="msedge.exe"; Args="--headless --disable-gpu --screenshot"},
    @{Name="Chrome"; Path="C:\Program Files\Google\Chrome\Application\chrome.exe"; Args="--headless --disable-gpu --screenshot"},
    @{Name="Edge"; Path="C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"; Args="--headless --disable-gpu --screenshot"}
)

$browserFound = $null
foreach ($browser in $browsers) {
    try {
        $null = Get-Command $browser.Path -ErrorAction Stop
        $browserFound = $browser
        break
    } catch {
        # Try next browser
    }
}

if ($browserFound) {
    Write-Host "✓ Found browser: $($browserFound.Name)" -ForegroundColor Green
    
    # Get full path to HTML file
    $htmlFile = Join-Path (Get-Location) "screenshot_generator.html"
    $htmlUri = "file:///$($htmlFile -replace '\\', '/')"
    
    Write-Host "📄 HTML file: $htmlFile" -ForegroundColor Yellow
    Write-Host "🌐 URI: $htmlUri" -ForegroundColor Yellow
    Write-Host ""
    
    if (Test-Path $htmlFile) {
        Write-Host "🚀 Generating screenshots..." -ForegroundColor Cyan
        Write-Host ""
        
        # Generate screenshot using headless browser
        $outputFile = Join-Path $OutputDir "spendflux_screenshots.png"
        $args = "$($browserFound.Args) --window-size=$Width,$Height --screenshot=`"$outputFile`" `"$htmlUri`""
        
        try {
            Start-Process -FilePath $browserFound.Path -ArgumentList $args -Wait -NoNewWindow
            
            if (Test-Path $outputFile) {
                Write-Host "✅ Screenshot generated successfully!" -ForegroundColor Green
                Write-Host "   Location: $outputFile" -ForegroundColor Cyan
                
                $fileInfo = Get-Item $outputFile
                $fileSizeKB = [math]::Round($fileInfo.Length / 1KB, 2)
                Write-Host "   Size: $fileSizeKB KB" -ForegroundColor Cyan
                
                # Check if file size is reasonable
                if ($fileInfo.Length -gt 8MB) {
                    Write-Host "⚠️  Warning: File size exceeds 8 MB limit!" -ForegroundColor Yellow
                } else {
                    Write-Host "   ✓ File size is within 8 MB limit" -ForegroundColor Green
                }
            } else {
                Write-Host "❌ Screenshot generation failed" -ForegroundColor Red
            }
        } catch {
            Write-Host "❌ Error running browser: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ HTML file not found: $htmlFile" -ForegroundColor Red
    }
} else {
    Write-Host "⚠️  No suitable browser found for headless capture" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📋 Manual Instructions:" -ForegroundColor Cyan
    Write-Host "1. Open screenshot_generator.html in your browser" -ForegroundColor White
    Write-Host "2. Use browser dev tools or screenshot extension" -ForegroundColor White
    Write-Host "3. Capture each phone mockup section" -ForegroundColor White
    Write-Host "4. Save as PNG files in $OutputDir" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 Alternative Methods:" -ForegroundColor Cyan
    Write-Host "• Install Chrome or Edge browser" -ForegroundColor White
    Write-Host "• Use online HTML to image converters" -ForegroundColor White
    Write-Host "• Use browser screenshot extensions" -ForegroundColor White
}

Write-Host ""
Write-Host "📱 Screenshot Specifications:" -ForegroundColor Cyan
Write-Host "   Dimensions: $Width × $Height px" -ForegroundColor White
Write-Host "   Format: PNG" -ForegroundColor White
Write-Host "   Max Size: 8 MB each" -ForegroundColor White
Write-Host "   Aspect Ratio: 9:16 (portrait)" -ForegroundColor White
Write-Host ""

Write-Host "📂 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Review generated screenshots" -ForegroundColor White
Write-Host "2. Create individual files for each screen" -ForegroundColor White
Write-Host "3. Upload to Google Play Console" -ForegroundColor White
Write-Host "4. Preview and publish!" -ForegroundColor White
Write-Host ""

Write-Host "🎉 SpendFlux screenshots ready for Play Store!" -ForegroundColor Green