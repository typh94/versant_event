# Versant Event — Firebase Firestore Integration

This project has Firestore wired-in with a small service layer so you can:
- Admins: create forms (documents) in a `forms` collection and view all forms in real time.
- Technicians: open a form, update fields, and save back to the same document.

Below are the steps to initialize Firebase for Flutter and examples to connect to Firestore.

---

## 1) Add Firebase to your Flutter app

We already added the dependencies:

pubspec.yaml
- firebase_core
- cloud_firestore

Run this locally to fetch packages:
- flutter pub get

### Use FlutterFire CLI to configure platforms
1. Install the CLI (if not installed):
   - dart pub global activate flutterfire_cli
2. Log in to Firebase and select your project:
   - firebase login
3. Configure your Flutter app:
   - flutterfire configure
   - Select your Firebase project
   - Select platforms (Android, iOS, Web, macOS, Windows) you need

This command generates lib/firebase_options.dart and injects platform files:
- Android: android/app/google-services.json
- iOS/macOS: ios/Runner/GoogleService-Info.plist (and Settings changes)
- Web: web/firebase-config.js (injected via firebase_options.dart)

Commit the generated files to your repo if you share the app.

---

## 2) Initialize Firebase in Flutter

File: lib/main.dart

We included a basic initialization so the app won’t crash if Firebase isn’t configured yet. For production, after running flutterfire configure, replace the initialization with the DefaultFirebaseOptions version below.

Recommended production initialization (after flutterfire configure creates firebase_options.dart):

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // ... then runApp(...)
}

Current fallback in the project (works once platform configs are present; web requires options):

import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // If web or configs aren’t present yet, follow the steps above
  }
  // runApp(...)
}

---

## 3) Firestore service for forms

A lightweight service is provided at lib/services/firestore_service.dart. It handles create, update, set (upsert), and realtime streams.

Key APIs:
- Future<String> createForm({Map<String, dynamic>? data, String? id})
- Future<void> updateForm(String id, Map<String, dynamic> fields)
- Future<void> setForm(String id, Map<String, dynamic> data, {bool merge = true})
- Stream<DocumentSnapshot<Map<String, dynamic>>> streamFormById(String id)
- Stream<QuerySnapshot<Map<String, dynamic>>> streamAllForms({int? limit})

Collection name: forms

---

## 4) Example usage

### Admin: Create a form

final id = await FirestoreService.instance.createForm(
  data: {
    'title': 'Venue inspection',
    'assignedTo': 'tech_123',
    'fields': {
      'lightsWorking': false,
      'notes': 'Initial draft',
    },
  },
);

### Technician: Open and update a form

// Open by id and listen in real time
StreamBuilder(
  stream: FirestoreService.instance.streamFormById(id),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    final doc = snapshot.data!; // DocumentSnapshot<Map<String, dynamic>>
    final data = doc.data() ?? {};
    // ... build UI from data
    return ElevatedButton(
      onPressed: () async {
        await FirestoreService.instance.updateForm(doc.id, {
          'fields.lightsWorking': true,
          'fields.notes': 'Checked and fixed',
        });
      },
      child: Text('Save changes'),
    );
  },
)

### Admin: View all forms and get live updates

StreamBuilder(
  stream: FirestoreService.instance.streamAllForms(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    final qs = snapshot.data!; // QuerySnapshot<Map<String, dynamic>>
    final docs = qs.docs;
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final d = docs[index];
        final data = d.data();
        return ListTile(
          title: Text(data['title'] ?? 'Untitled form'),
          subtitle: Text('Updated: ' + (data['updatedAt']?.toDate()?.toString() ?? '-')),
          onTap: () {
            // Navigate to detail screen for this form
          },
        );
      },
    );
  },
)

Notes:
- Dot notation like 'fields.lightsWorking' updates nested map fields.
- updatedAt is maintained automatically by the service using server timestamps.

---

## 5) Firestore rules (basic example)

Adjust to your auth model. The file firestore.rules exists in the repo — update it as needed.

Example development rules (open; don’t use in production):

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /forms/{formId} {
      allow read, write: if true; // Everyone can read/write (dev only)
    }
  }
}

Example for Admin/Technician with simple role field on user doc:

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAdmin() {
      return exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    function isTech() {
      return exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'tech';
    }

    match /forms/{formId} {
      allow create, read: if isAdmin();
      allow read, update: if isAdmin() || isTech();
    }
  }
}

---

## 6) Troubleshooting

### I don’t see my simulator data in Firebase (Firestore)
By default in this repo, draft saves now write to BOTH local SQLite/files and to Firestore (best‑effort). If Firestore is unreachable or rules block writes, the local save still succeeds and a debug log will note the remote failure.

Note: Diagnostics like the Firebase project block and Firestore connectivity probe are printed only in debug builds by default.

Quick checklist:
- Confirm Firebase is initialized: after app launch, check logs for "✅ Firebase initialized" and the FirebaseDiag block with your Project ID.
- Verify configs exist for your platform:
  - Android: android/app/google-services.json
  - iOS: ios/Runner/GoogleService-Info.plist
  - Web: lib/firebase_options.dart present and used by main()
- Ensure the correct Firebase project: compare Project ID in logs with the one in Firebase console you’re looking at.
- Test Firestore connectivity: logs should show "Firestore connectivity: OK" from FirebaseDiag.
- Use FirestoreService for remote data: only calls like FirestoreService.instance.createForm(...) or setForm/updateForm will create/update docs in the forms collection.
- Rules: if reads/writes fail, check firestore.rules and the console for permission errors.

If you want all saves to also sync to Firestore, wire the relevant save buttons to FirestoreService (or I can add an opt-in sync path).

- On Web, Firebase.initializeApp() must include options. Ensure flutterfire configure generated lib/firebase_options.dart and use DefaultFirebaseOptions.currentPlatform.
- On Android/iOS, ensure google-services files are present and Gradle/Pods are synced.
- If you see Target of URI doesn't exist: 'package:firebase_core/firebase_core.dart', run flutter pub get.

---

## 7) Quick checklist

- [ ] Run flutter pub get
- [ ] Run flutterfire configure
- [ ] Replace main() initialization to use DefaultFirebaseOptions
- [ ] Ensure firestore.rules configured for your roles
- [ ] Use FirestoreService in your screens for Admin/Technician flows


---

## 8) Where is my data stored? (Android/Play Store, iOS, Web, Desktop)

This app persists user data locally first. Here’s how it works on each platform:

- Android (your Play Store build)
  - Local database: A SQLite database file named versant_event.db stored in the app’s private sandbox, managed by the sqflite plugin.
    - Typical path: /data/data/<your.app.id>/app_flutter/../databases/versant_event.db (location managed by Android; not user-accessible without root).
    - What’s inside: drafts (including their full JSON payload), reports/exports metadata, settings, and an index of images attached to drafts/reports.
  - Images/files: Image records store file paths pointing to your app’s files directory. The actual images are saved in the app’s private storage as standard files.
  - Privacy: Other apps cannot read this data. When the user uninstalls the app, Android deletes this sandbox, including the database and files.
  - Backups: On Android 6.0+ Auto Backup may back up app files to the user’s Google account unless disabled. If you have special compliance needs, configure android:allowBackup/autoBackup rules accordingly.

- iOS (App Store)
  - Local database: Same structure, stored in the app’s sandbox Library/Application Support/Databases/versant_event.db (managed by iOS; not user-accessible).
  - Images/files: Saved under your app’s Documents/ or Library/ directories. Removed on uninstall.
  - iCloud backups: App data may be included in iCloud backups if enabled by the user and not excluded by app settings.

- Web
  - No device file system is used. Drafts are saved in the browser using local storage (via SharedPreferences for web). Data stays in the browser profile and can be cleared by the user.

- Desktop (macOS/Windows/Linux)
  - SQLite database and image files are stored in the app’s per-user data directory (platform-dependent), within the user account’s home directory and removed when the app’s data is deleted.

Cloud/remote storage
- By default, local saves DO NOT leave the device. There is no automatic upload to any server.
- If you enable and use Firebase/Firestore flows in this project, only the data you write via FirestoreService is stored remotely in your Firebase project; everything else remains on-device.

Technical details
- Database file name: versant_event.db
- Schema managed in: lib/services/database_helper.dart
  - SQLite enables foreign_keys and attempts to use WAL mode where supported; if not supported, it falls back gracefully.
  - Indexed queries on drafts, reports, and images for reliability and performance.
- Local persistence helpers: lib/services/storage_service.dart
  - Handles JSON draft persistence and web storage fallbacks.

Uninstall and data removal
- Uninstalling the app removes the app sandbox on Android/iOS, which deletes the SQLite database and any files/images saved by the app.
- Inside the app, user-initiated delete actions remove the corresponding rows/files from the database and storage.

If you want a different behavior (e.g., always sync to cloud, or exclude some data from backups), let me know and I can configure it.


---

## 9) Cross-device visibility (Admin vs Technician)

With the current setup, drafts/forms are written to BOTH local SQLite (for offline/fast access) and to Firestore (cloud sync). This means:

- Different phones signed into the same Firebase project will see the same Firestore documents.
- Admin view:
  - Use FirestoreService.streamAllForms() to see every form updated in real-time across devices.
- Technician view:
  - Use FirestoreService.streamFormsByOwner(owner) to see only that technician’s forms (owner is preserved on updates by StorageService.saveDraft).
- Offline behavior:
  - Local SQLite retains data on-device; Firestore sync occurs best-effort. When the network is available and rules allow, Firestore is updated and all devices receive the change.

Requirements for this to work in production:
- Ensure all platforms are configured to the SAME Firebase project (compare Project ID from FirebaseDiag logs).
- Firestore must be enabled, and security rules must allow the reads/writes you need (Admin: read all; Technician: read own). During development, permissive rules can be used; for production, prefer authenticated, role-based rules.
- Deploy rules from this repo’s firestore.rules using the Firebase CLI (firebase deploy --only firestore:rules).

Quick wiring guide:
- Admin list screen: subscribe to FirestoreService.streamAllForms().
- Technician list screen: subscribe to FirestoreService.streamFormsByOwner(currentUserIdOrName).
- Detail/edit screen: continue saving via StorageService.saveDraft(...), which dual-writes to Firestore using the same document ID, so updates propagate to other devices instantly.

Troubleshooting:
- If you see [cloud_firestore/permission-denied], your rules in the active project do not allow the operation. Deploy updated rules or sign in to an authorized account.
- If nothing appears in the console, confirm the app is pointed to the same project as your console session (check FirebaseDiag block) and that Firestore is enabled.
