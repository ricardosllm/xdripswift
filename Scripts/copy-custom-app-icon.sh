#!/bin/bash

# Script to copy custom app icons to the primary AppIcon.appiconset
# This allows developers to use their preferred icon as the primary app icon
# while keeping the original icons safe

# Get the custom icon name from build settings
CUSTOM_ICON_NAME="${XDRIP_PRIMARY_APP_ICON}"

# Exit if no custom icon is specified
if [ -z "$CUSTOM_ICON_NAME" ]; then
    echo "No custom app icon specified. Using default icons."
    exit 0
fi

echo "Setting up custom app icon: $CUSTOM_ICON_NAME"

# Paths
SRCROOT="${SRCROOT:-$(pwd)}"
ICONS_DIR="$SRCROOT/xdrip/Resources/Assets.xcassets/AppIcon.appiconset"
CUSTOM_ICONS_DIR="$SRCROOT/xdrip/Resources/CustomAppIcons/$CUSTOM_ICON_NAME"
ORIGINAL_ICONS_DIR="$SRCROOT/xdrip/Resources/CustomAppIcons/Original"

# Create directories if they don't exist
mkdir -p "$CUSTOM_ICONS_DIR"
mkdir -p "$ORIGINAL_ICONS_DIR"

# Function to backup original icons (only once)
backup_original_icons() {
    if [ ! -f "$ORIGINAL_ICONS_DIR/.backed_up" ]; then
        echo "Backing up original icons..."
        cp -R "$ICONS_DIR"/* "$ORIGINAL_ICONS_DIR/"
        touch "$ORIGINAL_ICONS_DIR/.backed_up"
        echo "Original icons backed up to $ORIGINAL_ICONS_DIR"
    fi
}

# Function to restore original icons
restore_original_icons() {
    if [ -f "$ORIGINAL_ICONS_DIR/.backed_up" ]; then
        echo "Restoring original icons..."
        cp -R "$ORIGINAL_ICONS_DIR"/* "$ICONS_DIR/"
        echo "Original icons restored"
    fi
}

# Function to copy custom icons
copy_custom_icons() {
    echo "Copying custom icons from $CUSTOM_ICONS_DIR..."
    
    # Check if custom icon directory exists
    if [ ! -d "$CUSTOM_ICONS_DIR" ]; then
        echo "Error: Custom icon directory not found: $CUSTOM_ICONS_DIR"
        echo "Please create this directory and add your custom icons."
        exit 1
    fi
    
    # Check if custom icons exist
    if [ -z "$(ls -A "$CUSTOM_ICONS_DIR"/*.png 2>/dev/null)" ]; then
        echo "Error: No PNG files found in $CUSTOM_ICONS_DIR"
        echo "Please add your custom icon PNG files."
        exit 1
    fi
    
    # Copy all PNG files from custom directory to AppIcon.appiconset
    cp "$CUSTOM_ICONS_DIR"/*.png "$ICONS_DIR/"
    echo "Custom icons copied successfully"
}

# Main logic
case "$CUSTOM_ICON_NAME" in
    "Original"|"Default"|"")
        restore_original_icons
        ;;
    *)
        backup_original_icons
        copy_custom_icons
        ;;
esac

echo "App icon setup complete"