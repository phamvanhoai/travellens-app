# TravelLens Customer App

Flutter client for TravelLens customers. Admin and staff features intentionally remain in the Next.js application.

## Stack

- Flutter / Dart
- Riverpod
- Dio
- GoRouter
- Flutter Secure Storage

## Run

The default API URL is the deployed TravelLens backend:

`https://travellens-gamma.vercel.app/api`

```powershell
flutter pub get
flutter run
```

To use a different backend temporarily:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api
```

For a physical device using a local backend, replace the host with the development computer's LAN address.

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
