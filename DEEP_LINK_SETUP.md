# Deep Link Setup for Invitation Links

The invitation links now use deep linking format: `costify://invite/{invitationId}`

## How It Works

1. **Link Format**: `costify://invite/{invitationId}`
   - Example: `costify://invite/abc123xyz`

2. **When User Clicks Link**:
   - If Costify app is installed: Opens the app directly to the invitation screen
   - If app is not installed: Shows an error (user needs to install the app first)

## Configuration

### Android ✅ (Already Configured)
The `AndroidManifest.xml` has been updated with deep link intent filter:
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data
        android:scheme="costify"
        android:host="invite"/>
</intent-filter>
```

### iOS ✅ (Already Configured)
The `Info.plist` has been updated with URL scheme:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>costify</string>
        </array>
    </dict>
</array>
```

## Testing Deep Links

### Android
```bash
adb shell am start -W -a android.intent.action.VIEW -d "costify://invite/TEST_ID" com.costify.costify
```

### iOS (Simulator)
```bash
xcrun simctl openurl booted "costify://invite/TEST_ID"
```

## Alternative: Manual Entry

If deep links don't work, users can:
1. Open the Costify app
2. The app should have a way to manually enter invitation ID (can be added as a feature)
3. Or share the invitation ID separately

## Troubleshooting

1. **Link doesn't open app**: 
   - Make sure the app is installed
   - Check that deep link configuration is correct
   - Try manually entering the invitation ID

2. **"Page not found" error**:
   - This happens when clicking the link in a browser
   - Deep links only work when the app is installed
   - Share the invitation ID separately as a fallback

3. **Link format**:
   - Current: `costify://invite/{id}`
   - This is a mobile deep link, not a web URL
   - It will only work when the app is installed

## Future Improvements

Consider adding:
1. A manual invitation ID entry screen in the app
2. Universal links (https://costify.app/invite/{id}) that work for both web and app
3. QR code generation for easier sharing

