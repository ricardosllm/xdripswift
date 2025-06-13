#!/bin/bash

# Generate all required icon sizes for Cyborg icon set
# Using the 180x180 (3x) icon as the source

SOURCE_ICON="xDrip/Resources/AlternateIcons/AppIcon-Cyborg-Classic@3x.png"
OUTPUT_DIR="xdrip/Resources/CustomAppIcons/Cyborg"

if [ ! -f "$SOURCE_ICON" ]; then
    echo "Source icon not found: $SOURCE_ICON"
    exit 1
fi

echo "Generating Cyborg icon set from $SOURCE_ICON..."

# iPhone icons
magick "$SOURCE_ICON" -resize 40x40 "$OUTPUT_DIR/Icon-21.png"      # 20pt@2x
magick "$SOURCE_ICON" -resize 60x60 "$OUTPUT_DIR/Icon-30.png"      # 20pt@3x (iPad 1x, 29pt@1x)
magick "$SOURCE_ICON" -resize 40x40 "$OUTPUT_DIR/Icon-41.png"      # 20pt@2x
magick "$SOURCE_ICON" -resize 40x40 "$OUTPUT_DIR/Icon-42.png"      # 20pt@2x (iPad)
magick "$SOURCE_ICON" -resize 40x40 "$OUTPUT_DIR/Icon-43.png"      # 40pt@1x (iPad)
magick "$SOURCE_ICON" -resize 58x58 "$OUTPUT_DIR/Icon-59.png"      # 29pt@2x
magick "$SOURCE_ICON" -resize 60x60 "$OUTPUT_DIR/Icon-61.png"      # 20pt@3x
magick "$SOURCE_ICON" -resize 58x58 "$OUTPUT_DIR/Icon-62.png"      # 29pt@2x (iPad)
magick "$SOURCE_ICON" -resize 76x76 "$OUTPUT_DIR/Icon-77.png"      # 76pt@1x (iPad)
magick "$SOURCE_ICON" -resize 80x80 "$OUTPUT_DIR/Icon-81.png"      # 40pt@2x
magick "$SOURCE_ICON" -resize 80x80 "$OUTPUT_DIR/Icon-82.png"      # 40pt@2x (iPad)
magick "$SOURCE_ICON" -resize 87x87 "$OUTPUT_DIR/Icon-89.png"      # 29pt@3x
magick "$SOURCE_ICON" -resize 120x120 "$OUTPUT_DIR/Icon-121.png"   # 40pt@3x, 60pt@2x
magick "$SOURCE_ICON" -resize 120x120 "$OUTPUT_DIR/Icon-122.png"   # 60pt@2x
magick "$SOURCE_ICON" -resize 152x152 "$OUTPUT_DIR/Icon-153.png"   # 76pt@2x (iPad)
magick "$SOURCE_ICON" -resize 167x167 "$OUTPUT_DIR/Icon-168.png"   # 83.5pt@2x (iPad)
magick "$SOURCE_ICON" -resize 180x180 "$OUTPUT_DIR/Icon-181.png"   # 60pt@3x
magick "$SOURCE_ICON" -resize 1024x1024 "$OUTPUT_DIR/Icon-1025.png" # App Store

# Copy Contents.json
cp "xdrip/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json" "$OUTPUT_DIR/"

echo "Cyborg icon set generated in $OUTPUT_DIR"
echo "Icon count: $(ls -1 "$OUTPUT_DIR"/*.png | wc -l) PNG files"