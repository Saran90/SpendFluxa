# Creating 512x512 Play Store Icon

## Requirements
- PNG or JPEG format
- Up to 1 MB file size
- Exactly 512 px by 512 px
- 32-bit PNG with alpha channel (recommended)
- No rounded corners (Google Play will apply them)

## Option 1: Use Online Tools (Easiest)

### Method A: Use an Online Image Resizer
1. Go to one of these free online tools:
   - https://www.iloveimg.com/resize-image
   - https://www.resizepixel.com/
   - https://imageresizer.com/

2. Upload your current icon: `assets/icons/app_icon.png`

3. Set dimensions to exactly **512 x 512 pixels**

4. Download the resized image

5. Save it as `play_store_icon_512.png` in your project root or a convenient location

### Method B: Use Icon Generator
1. Go to: https://icon.kitchen/
2. Upload your icon
3. Select "Play Store" option
4. Download the 512x512 version

## Option 2: Use Flutter Package

Run this command to generate all app icons:
```bash
dart run flutter_launcher_icons
```

This will generate icons for Android and iOS. However, for the Play Store 512x512 icon, you may need to manually resize it using one of the online tools above.

## Option 3: Use Image Editing Software

### Using GIMP (Free)
1. Download GIMP: https://www.gimp.org/
2. Open `assets/icons/app_icon.png`
3. Go to Image → Scale Image
4. Set Width: 512, Height: 512
5. Export as PNG: File → Export As → `play_store_icon_512.png`

### Using Photoshop
1. Open `assets/icons/app_icon.png`
2. Image → Image Size
3. Set Width: 512 px, Height: 512 px
4. Save As → PNG → `play_store_icon_512.png`

### Using Paint.NET (Windows, Free)
1. Download Paint.NET: https://www.getpaint.net/
2. Open `assets/icons/app_icon.png`
3. Image → Resize
4. Set to 512 x 512 pixels
5. Save as `play_store_icon_512.png`

## Option 4: Use ImageMagick (Command Line)

If you have ImageMagick installed:
```bash
magick convert assets/icons/app_icon.png -resize 512x512 play_store_icon_512.png
```

To install ImageMagick on Windows:
```bash
winget install ImageMagick.ImageMagick
```

## Design Guidelines for Play Store Icon

1. **No transparency in background** (unless intentional design)
2. **Safe zone**: Keep important elements within the center 66% of the icon
3. **No text** (unless it's part of your logo)
4. **High contrast** for visibility
5. **Consistent with your app's branding**
6. **Test on different backgrounds** (light and dark)

## Verification

After creating your icon, verify:
- ✓ Dimensions: Exactly 512 x 512 px
- ✓ File size: Under 1 MB
- ✓ Format: PNG (32-bit with alpha) or JPEG
- ✓ No rounded corners applied
- ✓ Clear and recognizable at small sizes

## Where to Upload

When publishing to Play Store:
1. Go to Google Play Console
2. Navigate to: Store presence → Main store listing
3. Scroll to "App icon" section
4. Upload your 512x512 icon

## Current Icon Location
Your current app icon is located at: `assets/icons/app_icon.png`

## Recommended: Create a dedicated folder for store assets
```
store_assets/
  ├── play_store_icon_512.png
  ├── feature_graphic_1024x500.png
  └── screenshots/
```
