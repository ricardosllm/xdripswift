# Custom App Icons

This directory allows developers to use custom primary app icons for their personal builds.

## Why Custom App Icons?

While xDrip4iOS supports changing app icons through Settings, iOS limitations mean that:
- Notifications always show the primary app icon (from Info.plist)
- The primary icon cannot be changed at runtime

This feature allows developers to build the app with their preferred icon as the primary icon, which will then show in all notifications.

## How to Use

### Simple Method (Recommended)

1. **Set your preferred icon**:
   ```bash
   ./Scripts/set-primary-icon.sh Cyborg
   ```

2. **Clean build folder** in Xcode (Cmd+Shift+K)

3. **Build and run** the project

To restore the default icon:
```bash
./Scripts/set-primary-icon.sh default
```

### Automatic Method (Via Build Configuration)

1. **Create your xDripOverride.xcconfig file** (if you haven't already):
   ```bash
   cp xDrip/xDripOverride.xcconfig.example xDrip/xDripOverride.xcconfig
   ```

2. **Add this line to your xDripOverride.xcconfig**:
   ```
   XDRIP_PRIMARY_APP_ICON = Cyborg
   ```

3. **Add a Build Phase** to the xDrip target in Xcode:
   - Select the xDrip target
   - Go to Build Phases
   - Click + → New Run Script Phase
   - Add this script:
   ```bash
   "${SRCROOT}/Scripts/copy-custom-app-icon.sh"
   ```
   - Drag this phase to run **before** "Copy Bundle Resources"

4. **Clean and rebuild** the project

## Available Icon Sets

- `Cyborg` - The Cyborg icon variant

## Creating Your Own Icon Set

1. Create a new directory: `xdrip/Resources/CustomAppIcons/YourIconName/`
2. Add all required icon sizes (see existing sets for examples)
3. Copy `Contents.json` from the default AppIcon.appiconset
4. Update your xDripOverride.xcconfig: `XDRIP_PRIMARY_APP_ICON = YourIconName`

## Important Notes

- Custom icon directories are gitignored and won't be committed
- The script backs up original icons to `CustomAppIcons/Original/`
- To restore default icons, comment out the `XDRIP_PRIMARY_APP_ICON` line