// Run this script to generate app icons
// Usage: flutter run -t tool/generate_icon.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const IconGeneratorApp());
}

class IconGeneratorApp extends StatelessWidget {
  const IconGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: IconGeneratorScreen(),
    );
  }
}

class IconGeneratorScreen extends StatelessWidget {
  final GlobalKey _iconKey = GlobalKey();

  IconGeneratorScreen({super.key});

  Future<void> _saveIcon(BuildContext context) async {
    try {
      RenderRepaintBoundary boundary =
          _iconKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 4.0); // 1024x1024
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_icon.png');
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Icon saved to: ${file.path}')),
        );
      }
      print('Icon saved to: ${file.path}');
    } catch (e) {
      print('Error saving icon: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Costify Icon Generator')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RepaintBoundary(
              key: _iconKey,
              child: const SizedBox(
                width: 256,
                height: 256,
                child: AppIconWidget(),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _saveIcon(context),
              child: const Text('Save Icon as PNG'),
            ),
            const SizedBox(height: 16),
            const Text(
              'After saving, copy the file to:\nassets/icons/app_icon.png\n\nThen run:\nflutter pub run flutter_launcher_icons',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// The actual app icon widget
class AppIconWidget extends StatelessWidget {
  const AppIconWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(256, 256),
      painter: _AppIconPainter(),
    );
  }
}

class _AppIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;

    // Background gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
      ).createShader(Rect.fromLTWH(0, 0, s, s));

    // Orange gradient for accents
    final orangePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF7043), Color(0xFFF4511E)],
      ).createShader(Rect.fromLTWH(0, 0, s, s));

    final whitePaint = Paint()..color = Colors.white;
    final bluePaint = Paint()..color = const Color(0xFF1565C0);

    // Draw rounded background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, s, s),
      Radius.circular(s * 0.2),
    );
    canvas.drawRRect(bgRect, bgPaint);

    // Scale factors
    final scale = s / 512;

    // Building - Main tower
    canvas.save();
    canvas.translate(80 * scale, 70 * scale);

    // Main building rect
    final buildingRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(110 * scale, 100 * scale, 130 * scale, 250 * scale),
      Radius.circular(8 * scale),
    );
    canvas.drawRRect(buildingRect, whitePaint);

    // Windows - Row 1
    _drawWindow(canvas, 130 * scale, 125 * scale, 35 * scale, 40 * scale, bluePaint);
    _drawWindow(canvas, 185 * scale, 125 * scale, 35 * scale, 40 * scale, bluePaint);

    // Windows - Row 2
    _drawWindow(canvas, 130 * scale, 185 * scale, 35 * scale, 40 * scale, bluePaint);
    _drawWindow(canvas, 185 * scale, 185 * scale, 35 * scale, 40 * scale, bluePaint);

    // Windows - Row 3
    _drawWindow(canvas, 130 * scale, 245 * scale, 35 * scale, 40 * scale, bluePaint);
    _drawWindow(canvas, 185 * scale, 245 * scale, 35 * scale, 40 * scale, bluePaint);

    // Roof triangle
    final roofPath = Path()
      ..moveTo(175 * scale, 30 * scale)
      ..lineTo(70 * scale, 100 * scale)
      ..lineTo(280 * scale, 100 * scale)
      ..close();
    canvas.drawPath(roofPath, orangePaint);

    // Chimney
    final chimneyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(220 * scale, 50 * scale, 25 * scale, 50 * scale),
      Radius.circular(3 * scale),
    );
    canvas.drawRRect(chimneyRect, orangePaint);

    canvas.restore();

    // Cost badge
    final badgeCenterX = 380 * scale;
    final badgeCenterY = 380 * scale;
    final badgeRadius = 70 * scale;

    // Orange circle
    canvas.drawCircle(
      Offset(badgeCenterX, badgeCenterY),
      badgeRadius,
      orangePaint,
    );

    // White ring
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * scale;
    canvas.drawCircle(
      Offset(badgeCenterX, badgeCenterY),
      55 * scale,
      ringPaint,
    );

    // Dollar sign
    final textPainter = TextPainter(
      text: TextSpan(
        text: '\$',
        style: TextStyle(
          color: Colors.white,
          fontSize: 60 * scale,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        badgeCenterX - textPainter.width / 2,
        badgeCenterY - textPainter.height / 2,
      ),
    );
  }

  void _drawWindow(Canvas canvas, double x, double y, double w, double h, Paint paint) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
