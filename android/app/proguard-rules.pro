# BlockReels release keep rules (R8)
# Flutter engine entry points are kept by the Flutter Gradle plugin's bundled rules.

# Native state persisted via DataStore / JSON round-trips
-keep class com.blockreels.app.state.** { *; }
-keep class com.blockreels.app.detection.** { *; }
-keep class com.blockreels.app.disambiguation.** { *; }

# Kotlin coroutines internals safety net
-dontwarn kotlinx.coroutines.**
