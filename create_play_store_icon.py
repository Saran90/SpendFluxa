#!/usr/bin/env python3
"""
Script to create a 512x512 Play Store icon from your app icon
Requires: pip install Pillow
"""

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("❌ Pillow library not found!")
    print("\nTo install, run:")
    print("  pip install Pillow")
    print("\nOr use one of the other methods in CREATE_PLAY_STORE_ICON.md")
    sys.exit(1)


def create_play_store_icon(input_path="assets/icons/app_icon.png", 
                          output_path="play_store_icon_512.png"):
    """Create a 512x512 icon for Play Store"""
    
    print(f"🎨 Creating Play Store Icon (512x512)...")
    print(f"   Input: {input_path}")
    print(f"   Output: {output_path}")
    print()
    
    # Check if input exists
    if not Path(input_path).exists():
        print(f"❌ Error: Input icon not found at: {input_path}")
        sys.exit(1)
    
    try:
        # Open the image
        img = Image.open(input_path)
        print(f"✓ Loaded image: {img.size[0]}x{img.size[1]} ({img.mode})")
        
        # Convert to RGBA if needed (for transparency support)
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
            print(f"✓ Converted to RGBA mode")
        
        # Resize to 512x512 using high-quality resampling
        img_resized = img.resize((512, 512), Image.Resampling.LANCZOS)
        print(f"✓ Resized to 512x512")
        
        # Save as PNG
        img_resized.save(output_path, 'PNG', optimize=True)
        
        # Get file size
        file_size = Path(output_path).stat().st_size
        file_size_kb = file_size / 1024
        file_size_mb = file_size / (1024 * 1024)
        
        print()
        print("✅ Success! Play Store icon created:")
        print(f"   Location: {output_path}")
        print(f"   Size: {file_size_kb:.2f} KB ({file_size_mb:.2f} MB)")
        
        # Check file size
        if file_size > 1024 * 1024:  # 1 MB
            print()
            print("⚠️  Warning: File size exceeds 1 MB limit!")
            print("   You may need to compress it further.")
        else:
            print(f"   ✓ File size is within 1 MB limit")
        
        # Verify dimensions
        verify_img = Image.open(output_path)
        print(f"   Dimensions: {verify_img.size[0]}x{verify_img.size[1]}")
        
        if verify_img.size == (512, 512):
            print("   ✓ Dimensions are correct (512x512)")
        else:
            print("   ⚠️  Warning: Dimensions are not 512x512!")
        
        print()
        print("📋 Next steps:")
        print("1. Verify the icon looks good by opening:", output_path)
        print("2. Upload to Google Play Console → Store presence → Main store listing → App icon")
        print()
        
    except Exception as e:
        print(f"❌ Error creating icon: {e}")
        sys.exit(1)


if __name__ == "__main__":
    # You can customize these paths
    input_icon = "assets/icons/app_icon.png"
    output_icon = "play_store_icon_512.png"
    
    # Allow command line arguments
    if len(sys.argv) > 1:
        input_icon = sys.argv[1]
    if len(sys.argv) > 2:
        output_icon = sys.argv[2]
    
    create_play_store_icon(input_icon, output_icon)
