#!/bin/bash

# Script to manually set the primary app icon
# Usage: ./Scripts/set-primary-icon.sh [icon-name]
# Example: ./Scripts/set-primary-icon.sh Cyborg
# To restore default: ./Scripts/set-primary-icon.sh default

ICON_NAME="${1:-default}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

ICONS_DIR="$PROJECT_ROOT/xdrip/Resources/Assets.xcassets/AppIcon.appiconset"
CUSTOM_ICONS_DIR="$PROJECT_ROOT/xdrip/Resources/CustomAppIcons/$ICON_NAME"
ORIGINAL_ICONS_DIR="$PROJECT_ROOT/xdrip/Resources/CustomAppIcons/Original"

# Create directories if needed
mkdir -p "$ORIGINAL_ICONS_DIR"

# Backup original icons if not already done
if [ ! -f "$ORIGINAL_ICONS_DIR/.backed_up" ]; then
    echo "Backing up original icons..."
    cp -R "$ICONS_DIR"/* "$ORIGINAL_ICONS_DIR/"
    touch "$ORIGINAL_ICONS_DIR/.backed_up"
fi

case "$ICON_NAME" in
    "default"|"Default"|"original"|"Original")
        echo "Restoring default app icons..."
        cp -R "$ORIGINAL_ICONS_DIR"/*.png "$ICONS_DIR/"
        echo "✅ Default icons restored"
        ;;
    *)
        if [ ! -d "$CUSTOM_ICONS_DIR" ]; then
            echo "❌ Error: Icon set '$ICON_NAME' not found at:"
            echo "   $CUSTOM_ICONS_DIR"
            echo ""
            echo "Available icon sets:"
            ls -1 "$PROJECT_ROOT/xdrip/Resources/CustomAppIcons" | grep -v Original | grep -v README.md | grep -v .gitkeep
            exit 1
        fi
        
        echo "Setting primary app icon to: $ICON_NAME"
        cp "$CUSTOM_ICONS_DIR"/*.png "$ICONS_DIR/"
        echo "✅ Primary app icon set to $ICON_NAME"
        echo ""
        echo "⚠️  Remember to clean build folder (Cmd+Shift+K) and rebuild!"
        ;;
esac