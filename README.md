# BlockReels

BlockReels is an offline Android app that interrupts short-form videos on
Instagram, YouTube, Facebook and TikTok. It aims to keep ordinary areas such as
messaging, search and profiles usable. Detection depends on the layout of the
supported app and can change when that app updates.

## Using BlockReels

1. Install a build of BlockReels on Android 7.0 or later.
2. Open the app and follow the setup flow to enable its Android Accessibility service.
3. Choose the apps to protect and a blocking mode. You can also use schedules
   and set a PIN for changes to protected settings.

BlockReels uses Accessibility to recognize video screens and show an
interruption or leave the feed. It runs on-device. See the
[privacy policy](docs/privacy-policy.md) for what the app reads and stores.

## Build and test

Install Flutter 3.47.8 or later, JDK 17 and the Android SDK. Run these commands
from the repository root:

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --debug
```

For the Android JVM tests, run
`BLOCKREELS_OFFLINE=0 ./scripts/android-gradle.sh :app:testDebugUnitTest`
after setting up the SDK. A release build requires your own signing configuration
as shown in [key.properties.example](android/key.properties.example).
After dependencies are cached, the local verification command is
`./scripts/verify-local.sh release`.

Review changes to the Accessibility service on a real Android device before
sharing a release build.

## License

BlockReels source code is available under the [MIT License](LICENSE).
Third-party dependencies and build tools retain their own licenses.
