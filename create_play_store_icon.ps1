# PowerShell Script to Create 512x512 Play Store Icon
# This script requires ImageMagick to be installed

param(
    [string]$InputIcon = "assets/icons/app_icon.png",
    [string]$OutputIcon = "play_store_icon_512.png"
)

Write-Host "Creating Play Store Icon (512x512)..." -ForegroundColor Cyan

# Check if ImageMagick is installed
$magickPath = Get-Command magick -ErrorAction SilentlyContinue

if (-not $magickPath) {
    Write-Host "ImageMagick is not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "To install ImageMagick, run:" -ForegroundColor Yellow
    Write-Host "  winget install ImageMagick.ImageMagick" -ForegroundColor Green
    Write-Host ""
    Write-Host "Or download from: https://imagemagick.org/script/download.php" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative: Use online tools mentioned in CREATE_PLAY_STORE_ICON.md" -ForegroundColor Cyan
    exit 1
}

# Check if input file exists
if (-not (Test-Path $InputIcon)) {
    Write-Host "Error: Input icon not found at: $InputIcon" -ForegroundColor Red
    exit 1
}

# Create the 512x512 icon
Write-Host "Converting $InputIcon to 512x512..." -ForegroundColor Yellow

try {
    & magick convert $InputIcon -resize 512x512 -background none -gravity center -extent 512x512 $OutputIcon
    
    if (Test-Path $OutputIcon) {
        $fileInfo = Get-Item $OutputIcon
        $fileSizeKB = [math]::Round($fileInfo.Length / 1KB, 2)
        $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
        
        Write-Host ""
        Write-Host "✓ Success! Play Store icon created:" -ForegroundColor Green
        Write-Host "  Location: $OutputIcon" -ForegroundColor Cyan
        Write-Host "  Size: $fileSizeKB KB ($fileSizeMB MB)" -ForegroundColor Cyan
        
        if ($fileInfo.Length -gt 1MB) {
            Write-Host ""
            Write-Host "⚠ Warning: File size exceeds 1 MB limit!" -ForegroundColor Red
            Write-Host "  You may need to compress it further." -ForegroundColor Yellow
        } else {
            Write-Host "  ✓ File size is within 1 MB limit" -ForegroundColor Green
        }
        
        # Get image dimensions
        $dimensions = & magick identify -format "%wx%h" $OutputIcon
        Write-Host "  Dimensions: $dimensions" -ForegroundColor Cyan
        
        if ($dimensions -eq "512x512") {
            Write-Host "  ✓ Dimensions are correct (512x512)" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ Warning: Dimensions are not 512x512!" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "Error creating icon: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Verify the icon looks good by opening: $OutputIcon" -ForegroundColor White
Write-Host "2. Upload to Google Play Console → Store presence → Main store listing → App icon" -ForegroundColor White
Write-Host ""
