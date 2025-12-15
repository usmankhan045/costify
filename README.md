# Costify - Construction Expense Manager

A mobile application built with Flutter for managing construction project expenses. The app allows stakeholders to add and view expenses while admins can approve, track, and generate reports.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange)
![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-green)

## Features

### User Management
- **Email/Password Authentication** - Secure sign up and login
- **Google Sign-In** - Quick authentication with Google
- **Two-Factor Authentication (2FA)** - Extra security for sensitive actions
- **Role-Based Access Control** - Admin and Stakeholder roles

### Project Management
- Create and manage construction projects
- Set project budgets and track spending
- Invite stakeholders via shareable links
- Real-time budget utilization tracking

### Expense Management
- Add expenses with categories and payment methods
- Upload receipt photos
- Admin approval workflow
- Filter and search expenses
- Real-time expense tracking

### Security Features
- Secure data encryption
- OAuth 2.0 for Google authentication
- Role-based permissions
- Secure local storage for sensitive data

## Tech Stack

- **Framework**: Flutter
- **State Management**: Riverpod
- **Architecture**: MVVM
- **Backend**: Firebase
  - Firebase Authentication
  - Cloud Firestore
  - Firebase Storage
  - Firebase Messaging (Push Notifications)
- **Navigation**: GoRouter

## Project Structure

```
lib/
├── core/
│   ├── constants/       # App-wide constants
│   ├── theme/          # Theme configuration
│   ├── utils/          # Utility functions
│   ├── extensions/     # Dart extensions
│   ├── services/       # Core services
│   └── exceptions/     # Custom exceptions
├── data/
│   ├── models/         # Data models
│   ├── repositories/   # Data repositories
│   └── datasources/    # Remote/local data sources
├── presentation/
│   ├── common/         # Shared screens
│   ├── screens/        # Feature screens
│   └── widgets/        # Reusable widgets
├── providers/          # Riverpod providers
├── router/             # App routing
└── main.dart           # Entry point
```

## Getting Started

### Prerequisites

- Flutter SDK (3.8.0 or higher)
- Dart SDK
- Android Studio / Xcode
- Firebase project

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/costify.git
   cd costify
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Add iOS and Android apps to your Firebase project
   - Download configuration files:
     - `google-services.json` for Android (place in `android/app/`)
     - `GoogleService-Info.plist` for iOS (place in `ios/Runner/`)
   - Enable Authentication methods (Email/Password, Google)
   - Create Firestore database
   - Set up Storage bucket

4. **Run the app**
   ```bash
   flutter run
   ```

### Firebase Security Rules

**Firestore Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // Projects collection
    match /projects/{projectId} {
      allow read: if request.auth != null && 
        (resource.data.adminId == request.auth.uid || 
         request.auth.uid in resource.data.memberIds);
      allow create: if request.auth != null;
      allow update, delete: if resource.data.adminId == request.auth.uid;
    }
    
    // Expenses collection
    match /expenses/{expenseId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        (resource.data.createdBy == request.auth.uid || 
         isProjectAdmin(resource.data.projectId));
      allow delete: if request.auth != null && 
        resource.data.createdBy == request.auth.uid;
    }
    
    // Invitations collection
    match /invitations/{invitationId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
    }
  }
}
```

**Storage Rules:**
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /receipts/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    match /profiles/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
  }
}
```

## Building for Production

### Android
```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## Configuration

### Environment Variables

Create a `.env` file in the root directory:
```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_API_KEY=your-api-key
```

### App Configuration

Key configurations can be found in:
- `lib/core/constants/app_constants.dart` - App-wide constants
- `lib/core/theme/app_colors.dart` - Color palette
- `lib/core/theme/app_theme.dart` - Theme configuration

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support, email support@costify.app or create an issue in this repository.

---

Built with ❤️ using Flutter
