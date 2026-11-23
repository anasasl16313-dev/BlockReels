# Contributing to BlockReels

Use GitHub Issues for ordinary bugs and feature requests. For a security or
privacy vulnerability, follow [SECURITY.md](SECURITY.md).

## Set up and test

Use Flutter 3.47.8 or later, a JDK 17 installation, and the Android SDK.
From the project root, run:

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
```

For changes to Kotlin or Android, also run:

```sh
BLOCKREELS_OFFLINE=0 ./scripts/android-gradle.sh :app:testDebugUnitTest
```

When a change affects Accessibility, detection, or blocking overlays, include
any physical-device testing you were able to do. Check both a short-video feed
that should be interrupted and an ordinary screen, such as messaging or search,
that should remain usable.

## Open a pull request

1. Fork the public repository and make a branch from `main`.
2. Keep the change focused. Add or update a regression test when you fix a
   behavior that existing tests do not cover.
3. Describe the problem, what changed, and which checks you ran. For detection
   bugs, include the Android version, affected app and version, expected result,
   and actual result.

Keep app behavior offline and preserve the
[privacy policy](docs/privacy-policy.md). Use synthetic inputs or redact personal
content in any diagnostic material. Keep signing keys, credentials, local
settings, generated build files, and APKs out of source commits.

Contributions to the project are made under its MIT License. Submit only work
you have the right to share under that license.
