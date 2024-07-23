import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class NDIDisplay extends CustomPainter {
  ui.Image? image;

  NDIDisplay({this.image});

  @override
  void paint(Canvas canvas, Size size) {
    if (image != null) {
      final paint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 2
        ..style = PaintingStyle.fill;
      canvas.drawImage(image!, const Offset(0, 0), paint);
      // canvas.scale(1920 / 4 / image!.width, 1080 / 4 / image!.height);
      // canvas.scale(0.25, 0.25);
    }

    // canvas.drawRect(
    //     Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)),
    //     paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
