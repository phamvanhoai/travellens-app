# TravelLens Customer App

Flutter client for TravelLens customers. Admin and staff features intentionally remain in the Next.js application.

## Stack

- Flutter / Dart
- Riverpod
- Dio
- GoRouter
- Flutter Secure Storage

## Run

The Android emulator cannot reach the host using `localhost`, so the default API URL is `http://10.0.2.2:8000/api`.

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api
```

For a physical device, replace the host with the development computer's LAN address. For Flutter Web, use `http://localhost:4000/api`.

## Included customer modules

- Customer registration, login, secure token restore and logout
- Home and customer navigation
- Destinations and destination details
- Locations and location details
- Tours, tour details and customer booking
- Wishlist, customer bookings and payment history
- Location reviews
- Travel Feed and customer Travel Stories
- Group trips and invitations
- Blocked users
- Profile
- AI, map and 360-view entry points

Set backend CORS to allow the Flutter Web origin when running in a browser.
