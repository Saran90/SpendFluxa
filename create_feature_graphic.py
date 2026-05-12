#!/usr/bin/env python3
"""
Script to create a basic 1024×500 feature graphic for Play Store
Requires: pip install Pillow
"""

import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("❌ Pillow library not found!")
    print("\nTo install, run:")
    print("  pip install Pillow")
    print("\nOr use Canva for a better design: https://www.canva.com/")
    sys.exit(1)


def create_feature_graphic(
    app_icon_path="assets/icons/app_icon.png",
    output_path="feature_graphic_1024x500.png",
    app_name="SpendFlux",
    tagline="Track Your Expenses Effortlessly",
    bg_color="#4ECDC4",
    text_color="#FFFFFF"
):
    """Create a basic feature graphic for Play Store"""
    
    print("🎨 Creating Feature Graphic (1024×500)...")
    print(f"   App: {app_name}")
    print(f"   Tagline: {tagline}")
    print()
    
    # Convert hex to RGB
    def hex_to_rgb(hex_color):
        hex_color = hex_color.lstrip('#')
        return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))
    
    bg_rgb = hex_to_rgb(bg_color)
    text_rgb = hex_to_rgb(text_color)
    
    # Create image with background color
    img = Image.new('RGB', (1024, 500), bg_rgb)
    draw = ImageDraw.Draw(img)
    
    print("✓ Created canvas (1024×500)")
    
    # Try to load and add app icon
    icon_added = False
    if Path(app_icon_path).exists():
        try:
            icon = Image.open(app_icon_path)
            # Resize icon to 150×150
            icon = icon.resize((150, 150), Image.Resampling.LANCZOS)
            # Convert to RGB if needed (remove alpha)
            if icon.mode == 'RGBA':
                # Create white background
                icon_bg = Image.new('RGB', icon.size, bg_rgb)
                icon_bg.paste(icon, mask=icon.split()[3] if len(icon.split()) == 4 else None)
                icon = icon_bg
            # Paste icon at position (100, 175)
            img.paste(icon, (100, 175))
            icon_added = True
            print(f"✓ Added app icon from {app_icon_path}")
        except Exception as e:
            print(f"⚠ Could not load app icon: {e}")
    else:
        print(f"⚠ App icon not found at: {app_icon_path}")
    
    # Try to load fonts (fallback to default if not available)
    try:
        # Try to use a nice font
        font_large = ImageFont.truetype("arial.ttf", 72)
        font_small = ImageFont.truetype("arial.ttf", 32)
        print("✓ Loaded Arial font")
    except:
        try:
            # Try alternative font
            font_large = ImageFont.truetype("segoeui.ttf", 72)
            font_small = ImageFont.truetype("segoeui.ttf", 32)
            print("✓ Loaded Segoe UI font")
        except:
            # Use default font
            font_large = ImageFont.load_default()
            font_small = ImageFont.load_default()
            print("⚠ Using default font (install TrueType fonts for better results)")
    
    # Calculate text position
    text_x = 280 if icon_added else 100
    
    # Add app name
    draw.text((text_x, 180), app_name, fill=text_rgb, font=font_large)
    print(f"✓ Added app name: {app_name}")
    
    # Add tagline
    draw.text((text_x, 260), tagline, fill=text_rgb, font=font_small)
    print(f"✓ Added tagline: {tagline}")
    
    # Save the image
    img.save(output_path, 'PNG', optimize=True)
    
    # Get file info
    file_size = Path(output_path).stat().st_size
    file_size_kb = file_size / 1024
    file_size_mb = file_size / (1024 * 1024)
    
    print()
    print("✅ Success! Feature graphic created:")
    print(f"   Location: {output_path}")
    print(f"   Size: {file_size_kb:.2f} KB ({file_size_mb:.2f} MB)")
    
    if file_size > 15 * 1024 * 1024:  # 15 MB
        print()
        print("⚠️  Warning: File size exceeds 15 MB limit!")
    else:
        print(f"   ✓ File size is within 15 MB limit")
    
    # Verify dimensions
    verify_img = Image.open(output_path)
    print(f"   Dimensions: {verify_img.size[0]}×{verify_img.size[1]}")
    
    if verify_img.size == (1024, 500):
        print("   ✓ Dimensions are correct (1024×500)")
    else:
        print("   ⚠️  Warning: Dimensions are not 1024×500!")
    
    print()
    print("📝 Note: This is a basic template!")
    print("   For a professional design, use:")
    print("   • Canva: https://www.canva.com/")
    print("   • Figma: https://www.figma.com/")
    print("   • Or hire a designer on Fiverr")
    print()
    print("📤 Upload to:")
    print("   Google Play Console → Store presence → Main store listing → Feature graphic")
    print()


if __name__ == "__main__":
    # Default values
    app_icon = "assets/icons/app_icon.png"
    output = "feature_graphic_1024x500.png"
    
    # Allow command line arguments
    if len(sys.argv) > 1:
        app_icon = sys.argv[1]
    if len(sys.argv) > 2:
        output = sys.argv[2]
    
    # Customization options
    app_name = "SpendFlux"
    tagline = "Track Your Expenses Effortlessly"
    bg_color = "#4ECDC4"  # Teal
    text_color = "#FFFFFF"  # White
    
    # You can customize these:
    # tagline = "Smart Expense Management"
    # tagline = "Your Personal Finance Companion"
    # bg_color = "#2C3E50"  # Dark gray
    
    create_feature_graphic(
        app_icon_path=app_icon,
        output_path=output,
        app_name=app_name,
        tagline=tagline,
        bg_color=bg_color,
        text_color=text_color
    )
