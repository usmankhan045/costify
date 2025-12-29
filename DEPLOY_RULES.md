# Deploy Firestore Rules

The Google Sign-In issue is caused by Firestore security rules not being deployed. Follow these steps to deploy the rules:

## Option 1: Using Firebase CLI (Recommended)

1. Install Firebase CLI if you haven't already:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Deploy Firestore rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

## Option 2: Using Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `costify-1642a`
3. Go to **Firestore Database** → **Rules** tab
4. Copy the contents from `firestore.rules` file
5. Paste into the rules editor
6. Click **Publish**

## Verify Rules Are Deployed

After deploying, the rules should allow:
- Authenticated users to create their own user document
- Users to read any user profile
- Users to update/delete only their own profile

The rule for users collection is:
```
match /users/{userId} {
  allow read: if isAuthenticated();
  allow create: if isOwner(userId);  // User can create their own document
  allow update: if isOwner(userId);
  allow delete: if isOwner(userId);
}
```

This should fix the `PERMISSION_DENIED` error during Google sign-up.

