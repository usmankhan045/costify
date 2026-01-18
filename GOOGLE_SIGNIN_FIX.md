# Fix Google Sign-In Error Code 10

## Problem
The SHA-1 fingerprint in your `google-services.json` doesn't match the one your app is actually using.

## Your Current SHA-1 Fingerprint
```
A0:14:22:48:3B:C6:3E:ED:59:F7:1A:33:8B:89:E1:BA:78:DB:73:95
```

## Steps to Fix

### 1. Add SHA-1 to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **costify-1642a**
3. Click the ⚙️ gear icon → **Project settings**
4. Scroll down to **Your apps** section
5. Find your Android app (`com.costify.costify`)
6. Click **Add fingerprint**
7. Paste this SHA-1: `A0:14:22:48:3B:C6:3E:ED:59:F7:1A:33:8B:89:E1:BA:78:DB:73:95`
8. Click **Save**

### 2. Download Updated google-services.json

1. Still in Firebase Console → Project settings
2. In the **Your apps** section, find your Android app
3. Click **Download google-services.json**
4. Replace `android/app/google-services.json` with the downloaded file

### 3. Clean and Rebuild

```bash
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
flutter run
```

## Alternative: If You Have Multiple SHA-1s

If you're using different keystores for debug and release, you need to add **both** SHA-1 fingerprints to Firebase Console.

### Get Release SHA-1 (if you have a release keystore):
```bash
keytool -list -v -keystore android/app/your-release-key.jks -alias your-key-alias
```

Add all SHA-1 fingerprints you use to Firebase Console.

## Verify

After adding the SHA-1 and updating `google-services.json`, the Google Sign-In should work without error code 10.
