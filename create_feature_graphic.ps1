# PowerShell Script to Create 1024×500 Feature Graphic
# This script requires ImageMagick to be installed

param(
    [string]$AppIcon = "assets/icons/app_icon.png",
    [string]$OutputFile = "feature_graphic_1024x500.png",
    [string]$AppName = "SpendFlux",
    [string]$Tagline = "Track Your Expenses Effortlessly",
    [string]$BgColor = "#4ECDC4",
    [string]$TextColor = "#FFFFFF"
)

Write-Host "Creating Feature Graphic (1024×500)..." -ForegroundColor Cyan
Write-Host "App: $AppName" -ForegroundColor White
Write-Host "Tagline: $Tagline" -ForegroundColor White
Write-Host ""

# Check if ImageMagick is installed
$magickPath = Get-Command magick -ErrorAction SilentlyContinue

if (-not $magickPath) {
    Write-Host "ImageMagick is not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "This script requires ImageMagick for image processing." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To install ImageMagick, run:" -ForegroundColor Yellow
    Write-Host "  winget install ImageMagick.ImageMagick" -ForegroundColor Green
    Write-Host ""
    Write-Host "Or download from: https://imagemagick.org/script/download.php" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "RECOMMENDED: Use Canva for better results!" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Go to: https://www.canva.com/" -ForegroundColor White
    Write-Host "2. Create custom size: 1024 × 500 px" -ForegroundColor White
    Write-Host "3. Design your feature graphic" -ForegroundColor White
    Write-Host "4. Download as PNG" -ForegroundColor White
    Write-Host ""
    Write-Host "See CREATE_FEATURE_GRAPHIC.md for detailed instructions" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host "Creating basic feature graphic..." -ForegroundColor Yellow
Write-Host ""

try {
    # Create base image with background color
    & magick convert -size 1024x500 "xc:$BgColor" $OutputFile
    Write-Host "✓ Created canvas (1024×500) with background color" -ForegroundColor Green
    
    # Add app icon if it exists
    if (Test-Path $AppIcon) {
        Write-Host "✓ Adding app icon..." -ForegroundColor Yellow
        
        # Resize icon and composite it
        & magick convert $OutputFile `
            \( $AppIcon -resize 150x150 \) `
            -geometry +100+175 `
            -composite $OutputFile
        
        Write-Host "✓ Added app icon" -ForegroundColor Green
    } else {
        Write-Host "⚠ App icon not found at: $AppIcon" -ForegroundColor Yellow
    }
    
    # Add app name text
    Write-Host "✓ Adding text..." -ForegroundColor Yellow
    
    & magick convert $OutputFile `
        -font Arial -pointsize 72 -fill "$TextColor" `
        -annotate +280+230 "$AppName" `
        -font Arial -pointsize 32 -fill "$TextColor" `
        -annotate +280+280 "$Tagline" `
        $OutputFile
    
    Write-Host "✓ Added text (app name and tagline)" -ForegroundColor Green
    
    # Verify the output
    if (Test-Path $OutputFile) {
        $fileInfo = Get-Item $OutputFile
        $fileSizeKB = [math]::Round($fileInfo.Length / 1KB, 2)
        $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
        
        Write-Host ""
        Write-Host "✅ Success! Feature graphic created:" -ForegroundColor Green
        Write-Host "   Location: $OutputFile" -ForegroundColor Cyan
        Write-Host "   Size: $fileSizeKB KB ($fileSizeMB MB)" -ForegroundColor Cyan
        
        if ($fileInfo.Length -gt 15MB) {
            Write-Host ""
            Write-Host "⚠ Warning: File size exceeds 15 MB limit!" -ForegroundColor Red
        } else {
            Write-Host "   ✓ File size is within 15 MB limit" -ForegroundColor Green
        }
        
        # Get dimensions
        $dimensions = & magick identify -format "%wx%h" $OutputFile
        Write-Host "   Dimensions: $dimensions" -ForegroundColor Cyan
        
        if ($dimensions -eq "1024x500") {
            Write-Host "   ✓ Dimensions are correct (1024×500)" -ForegroundColor Green
        } else {
            Write-Host "   ⚠ Warning: Dimensions are not 1024×500!" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        Write-Host "📝 Note: This is a BASIC template!" -ForegroundColor Yellow
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "For a professional design, consider:" -ForegroundColor White
        Write-Host "  • Canva: https://www.canva.com/" -ForegroundColor Cyan
        Write-Host "  • Figma: https://www.figma.com/" -ForegroundColor Cyan
        Write-Host "  • Hire a designer on Fiverr ($10-30)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "See FEATURE_GRAPHIC_TEMPLATES.md for design ideas" -ForegroundColor White
        Write-Host ""
    }
    
} catch {
    Write-Host "Error creating feature graphic: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try using Canva instead: https://www.canva.com/" -ForegroundColor Yellow
    exit 1
}

Write-Host "📤 Next steps:" -ForegroundColor Cyan
Write-Host "1. Review the graphic: $OutputFile" -ForegroundColor White
Write-Host "2. Consider creating a professional version with Canva" -ForegroundColor White
Write-Host "3. Upload to: Google Play Console → Store presence → Feature graphic" -ForegroundColor White
Write-Host ""
