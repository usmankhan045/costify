# Costify App Icons

## Logo Files
- `costify_logo.svg` - Full logo with building and dollar sign
- `app_icon.svg` - Simplified app icon

## Generating App Icons

### Option 1: Use Online Tool (Easiest)

1. Open `app_icon.svg` in a browser or SVG editor
2. Export as PNG at 1024x1024 pixels
3. Save as `app_icon.png` in this folder
4. Run: `flutter pub run flutter_launcher_icons`

### Option 2: Use Figma/Canva

1. Create a new 1024x1024 canvas
2. Design elements:
   - Background: Rounded rectangle with gradient (#1976D2 to #0D47A1)
   - Building: White rectangle with blue windows
   - Roof: Orange triangle (#FF7043 to #F4511E)
   - Dollar badge: Orange circle with white "$" in bottom-right

### Option 3: Use Flutter Script

1. Run the icon generator:
   ```bash
   flutter run -t tool/generate_icon.dart
   ```
2. Click "Save Icon as PNG"
3. Copy the generated file to `assets/icons/app_icon.png`
4. Run: `flutter pub run flutter_launcher_icons`

## After Generating Icons

Run these commands to update all platform icons:

```bash
# Get dependencies
flutter pub get

# Generate icons for all platforms
flutter pub run flutter_launcher_icons
```

This will automatically update:
- Android: `android/app/src/main/res/mipmap-*/`
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- Web: `web/icons/`
- macOS: `macos/Runner/Assets.xcassets/AppIcon.appiconset/`
- Windows: `windows/runner/resources/app_icon.ico`

## Logo Colors

- Primary Blue: #1976D2 (light) / #0D47A1 (dark)
- Accent Orange: #FF7043 (light) / #F4511E (dark)
- White: #FFFFFF
- Window Blue: #1565C0
