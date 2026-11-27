# Firebase setup for MONOVA (Spark plan only)

This sets up the approved shared complaint store and owner email verification. The app keeps working offline
without any of this. Do not attach a billing account, and do not upgrade to Blaze.

## 1. Create the project (no billing)
1. Open https://console.firebase.google.com and create a project, for example `monova-hostel`.
2. Do not link a billing account. If the console asks for one, stop and tell the developer.

## 2. Turn on sign-in with email
1. Build → Authentication → Get started → Sign-in method → **Email/Password** → Enable.
2. Keep "Email link (passwordless)" off.

## 3. Create the database (Spark)
1. Build → Firestore Database → Create database → Production mode → choose a region in India if offered.
2. Open Rules, paste the contents of `firebase/firestore.rules`, and publish.

## 4. Register the apps and copy the settings
1. Project settings → Your apps → Add app → **Web**. Copy `apiKey`, `appId` (web), `messagingSenderId`, `projectId`.
2. Add an **Android** app with package name `com.monova.monova_app`. Copy its `appId`.
3. Do not commit these values to the repository. Keep them in your build notes or GitHub Actions secrets.

## 5. Build with the settings (passed at build time, not stored in code)
```
flutter build web --release --dart-define=MONOVA_OFFLINE=true \
  --dart-define=FIREBASE_PROJECT_ID=... --dart-define=FIREBASE_SENDER_ID=... \
  --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_WEB_APP_ID=...
```
For the Android build add `--dart-define=FIREBASE_ANDROID_APP_ID=...`.
Without these values the app runs offline and shows that cloud sync is not set up.

## 6. Test
1. Services → Owner account and sharing → Create account. Check the verification email arrives.
2. Open the link, then press "I have verified".
3. Register a complaint in a hostel. Check it appears in Firestore under `complaints` with only the approved fields.
4. Sign out, then confirm complaints still show on the phone.

## Limits and what is not included
- Firebase Spark has daily quotas. When one is reached, the app shows a quota message and keeps the data on the phone.
- Push notifications to another phone (Firebase Cloud Messaging) are not set up. They need device registration and a
  sender, which this Spark-only setup does not provide. Notifications appear only on the phone where the record is.
- Cloud Functions are not used.
- Residents without the app cannot read their complaint through Firebase yet: the store is readable only by the owner
  account. A secure tracking token for residents is a separate step needing another approval.
