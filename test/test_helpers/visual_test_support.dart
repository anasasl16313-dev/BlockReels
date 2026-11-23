import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uses the fonts bundled with the running Flutter SDK, rather than Ahem.
Future<void> loadDeviceTestFonts() async {
  var directory = File(Platform.resolvedExecutable).parent;
  Directory? fonts;
  while (directory.parent.path != directory.path) {
    final candidate =
        Directory('${directory.path}/bin/cache/artifacts/material_fonts');
    if (File('${candidate.path}/Roboto-Regular.ttf').existsSync()) {
      fonts = candidate;
      break;
    }
    directory = directory.parent;
  }
  if (fonts == null) {
    throw StateError('Flutter SDK material fonts were not found.');
  }
  final roboto = FontLoader('Roboto');
  for (final name in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf'
  ]) {
    roboto.addFont(Future.value(
        File('${fonts.path}/$name').readAsBytesSync().buffer.asByteData()));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(
          File('${fonts.path}/MaterialIcons-Regular.otf')
              .readAsBytesSync()
              .buffer
              .asByteData(),
        )))
      .load();
}

/// Opt in with STAGE6_PREVIEWS=/absolute/output/path when reviewing a layout.
Future<void> saveLayoutPreview(
    WidgetTester tester, Finder boundary, String name) async {
  final output = Platform.environment['STAGE6_PREVIEWS'];
  if (output == null) return;
  final render = tester.renderObject<RenderRepaintBoundary>(boundary);
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
