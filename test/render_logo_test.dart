import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _brand = Color(0xFFE06D53);

Future<void> _renderLogo(
  WidgetTester tester,
  Widget child,
  String path,
) async {
  tester.view.physicalSize = const Size(1024, 1024);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: key,
        child: Center(child: child),
      ),
    ),
  );
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render app icon', (tester) async {
    await _renderLogo(
      tester,
      Container(
        width: 1024,
        height: 1024,
        color: _brand,
        alignment: Alignment.center,
        child: const Icon(
          Icons.account_balance_wallet_rounded,
          size: 560,
          color: Colors.white,
        ),
      ),
      'assets/icon/logo.png',
    );
  });

  testWidgets('render adaptive foreground', (tester) async {
    await _renderLogo(
      tester,
      Container(
        width: 1024,
        height: 1024,
        color: Colors.transparent,
        alignment: Alignment.center,
        child: const Icon(
          Icons.account_balance_wallet_rounded,
          size: 620,
          color: Colors.white,
        ),
      ),
      'assets/icon/logo_foreground.png',
    );
  });
}
