import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest contains no INTERNET permission', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final permissionLines = manifest
        .split('\n')
        .where((line) => line.contains('<uses-permission'))
        .join('\n');
    expect(permissionLines, isNot(contains('android.permission.INTERNET')));
    expect(manifest, contains('MonitoringForegroundService'));
    expect(manifest, contains('FOREGROUND_SERVICE_SPECIAL_USE'));
  });

  test('Dart sources contain no network URLs or HTTP client usage', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in files) {
      final content = file.readAsStringSync();
      expect(
        RegExp(r'https?://').hasMatch(content),
        isFalse,
        reason: file.path,
      );
      expect(
        content.contains('dart:io') && content.contains('HttpClient'),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('release build requires a real keystore', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('key.properties'));
    expect(gradle, contains('BLOCKREELS_KEY_PROPERTIES'));
    expect(gradle, contains('create("release")'));
    expect(gradle, contains('GradleException'));
    expect(gradle,
        isNot(contains('signingConfig = signingConfigs.getByName("debug")')));
  });
}
