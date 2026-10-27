import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 보라색 몽환 성운 + 십자별 + 초승달 + 어몽어스 감성 배경 페인터
class CartoonSpaceBackgroundPainter extends CustomPainter {
  final double twinkleValue;

  const CartoonSpaceBackgroundPainter({required this.twinkleValue});

  @override
  void paint(Canvas canvas, Size size) {
    final bgRect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF140E36), Color(0xFF231754), Color(0xFF321E6E)],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // 물결 성운 레이어
    final nebulaPath1 = Path()
      ..moveTo(0, size.height * 0.35)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.18,
        size.width * 0.55,
        size.height * 0.38,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.55,
        size.width,
        size.height * 0.32,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      nebulaPath1,
      Paint()..color = const Color(0xFF43288C).withAlpha(140),
    );

    final nebulaPath2 = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.56,
        size.width * 0.68,
        size.height * 0.76,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.86,
        size.width,
        size.height * 0.68,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      nebulaPath2,
      Paint()..color = const Color(0xFF5E35B1).withAlpha(110),
    );

    _drawCartoonCloud(
      canvas,
      Offset(size.width * 0.12, size.height * 0.14),
      36,
      const Color(0xFF3B2378),
    );
    _drawCartoonCloud(
      canvas,
      Offset(size.width * 0.88, size.height * 0.84),
      42,
      const Color(0xFF281859),
    );

    // 초승달
    final moonCenter = Offset(size.width * 0.85, size.height * 0.14);
    canvas.drawCircle(
      moonCenter,
      22,
      Paint()
        ..color = const Color(0x55FFF59D)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: moonCenter, radius: 18)),
      Path()..addOval(
        Rect.fromCircle(center: moonCenter.translate(8, -4), radius: 15),
      ),
    );
    canvas.drawPath(crescent, Paint()..color = const Color(0xFFFFFDE7));
    canvas.drawPath(
      crescent,
      Paint()
        ..color = const Color(0xFF1A0F2E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // 반짝이는 십자별
    final starPositions = [
      Offset(size.width * 0.15, size.height * 0.22),
      Offset(size.width * 0.48, size.height * 0.12),
      Offset(size.width * 0.72, size.height * 0.28),
      Offset(size.width * 0.22, size.height * 0.62),
      Offset(size.width * 0.82, size.height * 0.58),
      Offset(size.width * 0.52, size.height * 0.86),
    ];
    for (var i = 0; i < starPositions.length; i++) {
      final scale = 0.7 + 0.4 * math.sin((twinkleValue * math.pi * 2) + i);
      _drawSparkleStar(canvas, starPositions[i], 7 * scale);
    }

    // 점선 항로
    final routePaint = Paint()
      ..color = Colors.white.withAlpha(70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final p1 = Offset(size.width * 0.27, size.height * 0.28);
    final p2 = Offset(size.width * 0.73, size.height * 0.28);
    final p3 = Offset(size.width * 0.27, size.height * 0.74);
    final p4 = Offset(size.width * 0.73, size.height * 0.74);
    _drawDashedLine(canvas, p1, p2, routePaint);
    _drawDashedLine(canvas, p1, p3, routePaint);
    _drawDashedLine(canvas, p2, p4, routePaint);
    _drawDashedLine(canvas, p3, p4, routePaint);
  }

  void _drawCartoonCloud(
    Canvas canvas,
    Offset center,
    double r,
    Color fillColor,
  ) {
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: r))
      ..addOval(
        Rect.fromCircle(
          center: center.translate(-r * 0.7, 6),
          radius: r * 0.75,
        ),
      )
      ..addOval(
        Rect.fromCircle(center: center.translate(r * 0.7, 6), radius: r * 0.75),
      );
    canvas.drawPath(path, Paint()..color = fillColor);
  }

  void _drawSparkleStar(Canvas canvas, Offset center, double radius) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFF9C4));
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLength = 7.0;
    const dashSpace = 7.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    var current = 0.0;
    while (current < distance) {
      final startX = p1.dx + (dx * current / distance);
      final startY = p1.dy + (dy * current / distance);
      final endDist = math.min(current + dashLength, distance);
      canvas.drawLine(
        Offset(startX, startY),
        Offset(
          p1.dx + (dx * endDist / distance),
          p1.dy + (dy * endDist / distance),
        ),
        paint,
      );
      current += dashLength + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CartoonSpaceBackgroundPainter oldDelegate) =>
      oldDelegate.twinkleValue != twinkleValue;
}

/// 어몽어스 스타일 굵은 외곽선 카툰 행성 위젯
class CartoonPlanetOrb extends StatelessWidget {
  final String planetId;
  final Color primaryColor;
  final Color secondaryColor;
  final double size;

  const CartoonPlanetOrb({
    super.key,
    required this.planetId,
    required this.primaryColor,
    required this.secondaryColor,
    this.size = 76,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.35,
      height: size * 1.15,
      child: CustomPaint(
        painter: _CartoonPlanetOrbPainter(
          planetId: planetId,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
        ),
      ),
    );
  }
}

class _CartoonPlanetOrbPainter extends CustomPainter {
  final String planetId;
  final Color primaryColor;
  final Color secondaryColor;

  const _CartoonPlanetOrbPainter({
    required this.planetId,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.40;
    const outlineColor = Color(0xFF1A0F2E);

    final planetRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius, Paint()..color = primaryColor);

    canvas.save();
    canvas.clipPath(Path()..addOval(planetRect));

    if (planetId == 'data_and_probability' ||
        planetId == 'change_and_relations') {
      final stripePaint = Paint()
        ..color = secondaryColor.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.26;
      canvas.drawLine(
        center.translate(-radius, -radius * 0.35),
        center.translate(radius, -radius * 0.65),
        stripePaint,
      );
      canvas.drawLine(
        center.translate(-radius, radius * 0.25),
        center.translate(radius, -radius * 0.05),
        stripePaint,
      );
    } else {
      final craterPaint = Paint()..color = secondaryColor.withAlpha(160);
      canvas.drawCircle(
        center.translate(-radius * 0.32, -radius * 0.22),
        radius * 0.22,
        craterPaint,
      );
      canvas.drawCircle(
        center.translate(radius * 0.35, radius * 0.18),
        radius * 0.16,
        craterPaint,
      );
      canvas.drawCircle(
        center.translate(-radius * 0.12, radius * 0.42),
        radius * 0.12,
        craterPaint,
      );
    }

    final crescentShadow = Path.combine(
      PathOperation.difference,
      Path()..addOval(planetRect),
      Path()..addOval(
        Rect.fromCircle(
          center: center.translate(-radius * 0.22, -radius * 0.22),
          radius: radius * 0.92,
        ),
      ),
    );
    canvas.drawPath(
      crescentShadow,
      Paint()..color = Colors.black.withAlpha(55),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-radius * 0.38, -radius * 0.38),
        width: radius * 0.36,
        height: radius * 0.20,
      ),
      Paint()..color = Colors.white.withAlpha(190),
    );
    canvas.restore();

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0,
    );

    if (planetId == 'data_and_probability' ||
        planetId == 'change_and_relations') {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.32);
      final ringRect = Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2.55,
        height: radius * 0.72,
      );
      canvas.drawArc(
        ringRect,
        0.15,
        math.pi - 0.3,
        false,
        Paint()
          ..color = outlineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9.0
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawArc(
        ringRect,
        0.15,
        math.pi - 0.3,
        false,
        Paint()
          ..color = secondaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CartoonPlanetOrbPainter oldDelegate) => false;
}

/// 어몽어스 크루원 마스코트 아바타
class CrewmateMascotBadge extends StatelessWidget {
  final Color suitColor;
  final double size;

  const CrewmateMascotBadge({
    super.key,
    this.suitColor = const Color(0xFFFFD54F),
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CartoonRocketMascotPainter(accentColor: suitColor),
      ),
    );
  }
}

class _CartoonRocketMascotPainter extends CustomPainter {
  final Color accentColor;

  const _CartoonRocketMascotPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    const outline = Color(0xFF1A0F2E);
    final strokePaint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // 1. 로켓 아래 불꽃 (주황/노랑 카툰 불꽃)
    final flamePath = Path()
      ..moveTo(w * 0.36, h * 0.74)
      ..quadraticBezierTo(w * 0.50, h * 0.98, w * 0.64, h * 0.74)
      ..close();
    canvas.drawPath(flamePath, Paint()..color = const Color(0xFFFF6D00));
    canvas.drawPath(flamePath, strokePaint);

    // 2. 양쪽 날개 핀 (accentColor 적용)
    final leftFin = Path()
      ..moveTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.12, h * 0.74)
      ..lineTo(w * 0.32, h * 0.72)
      ..close();
    final rightFin = Path()
      ..moveTo(w * 0.72, h * 0.52)
      ..lineTo(w * 0.88, h * 0.74)
      ..lineTo(w * 0.68, h * 0.72)
      ..close();
    canvas.drawPath(leftFin, Paint()..color = accentColor);
    canvas.drawPath(leftFin, strokePaint);
    canvas.drawPath(rightFin, Paint()..color = accentColor);
    canvas.drawPath(rightFin, strokePaint);

    // 3. 통통한 카툰 로켓 본체 (흰색/연보라 베이스)
    final bodyPath = Path()
      ..moveTo(w * 0.50, h * 0.10)
      ..quadraticBezierTo(w * 0.78, h * 0.34, w * 0.70, h * 0.74)
      ..lineTo(w * 0.30, h * 0.74)
      ..quadraticBezierTo(w * 0.22, h * 0.34, w * 0.50, h * 0.10)
      ..close();
    canvas.drawPath(bodyPath, Paint()..color = Colors.white);
    canvas.drawPath(bodyPath, strokePaint);

    // 4. 로켓 머리 고깔 포인트 컬러
    final nosePath = Path()
      ..moveTo(w * 0.50, h * 0.10)
      ..quadraticBezierTo(w * 0.64, h * 0.22, w * 0.66, h * 0.32)
      ..lineTo(w * 0.34, h * 0.32)
      ..quadraticBezierTo(w * 0.36, h * 0.22, w * 0.50, h * 0.10)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = accentColor);
    canvas.drawPath(nosePath, strokePaint);

    // 5. 중앙 동그란 우주선 창문 + 반사광
    final windowCenter = Offset(w * 0.50, h * 0.48);
    canvas.drawCircle(
      windowCenter,
      w * 0.13,
      Paint()..color = const Color(0xFF81D4FA),
    );
    canvas.drawCircle(windowCenter, w * 0.13, strokePaint);
    canvas.drawCircle(
      windowCenter.translate(-w * 0.04, -h * 0.04),
      w * 0.035,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _CartoonRocketMascotPainter oldDelegate) =>
      false;
}

/// 궤도 진입 시 카툰 궤도 아크 페인터
class CartoonOrbitArcPainter extends CustomPainter {
  final Color orbitColor;
  final Color secondaryColor;

  const CartoonOrbitArcPainter({
    required this.orbitColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final planetCenter = Offset(size.width * 0.88, size.height * 1.08);
    final planetRadius = size.height * 0.65;
    canvas.drawCircle(
      planetCenter,
      planetRadius,
      Paint()..color = orbitColor.withAlpha(90),
    );
    canvas.drawCircle(
      planetCenter,
      planetRadius,
      Paint()
        ..color = const Color(0xFF1A0F2E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0,
    );

    final path = Path()
      ..moveTo(size.width * 0.06, size.height * 0.80)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.68,
        size.width * 0.92,
        size.height * 0.22,
      );

    canvas.drawPath(
      path,
      Paint()
        ..color = secondaryColor.withAlpha(70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF1A0F2E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = secondaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CartoonOrbitArcPainter oldDelegate) => false;
}

/// 오각형 스킬 레이더 차트 페인터
class PentagonRadarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;

  const PentagonRadarChartPainter({required this.values, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 6);
    final radius = math.min(size.width, size.height) * 0.36;

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final outerFillPaint = Paint()
      ..color = const Color(0xFFF7F7FA)
      ..style = PaintingStyle.fill;

    for (final scale in [1.0, 0.66, 0.33]) {
      final path = Path();
      for (var i = 0; i < 5; i++) {
        final angle = -math.pi / 2 + (2 * math.pi * i / 5);
        final pt = Offset(
          center.dx + radius * scale * math.cos(angle),
          center.dy + radius * scale * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      if (scale == 1.0) canvas.drawPath(path, outerFillPaint);
      canvas.drawPath(path, gridPaint);
    }

    for (var i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / 5);
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        ),
        gridPaint,
      );

      final labelPt = Offset(
        center.dx + (radius + 22) * math.cos(angle),
        center.dy + (radius + 18) * math.sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A5568),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(labelPt.dx - tp.width / 2, labelPt.dy - tp.height / 2),
      );
    }

    final dataPath = Path();
    for (var i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / 5);
      final v = values[i].clamp(0.1, 1.0);
      final pt = Offset(
        center.dx + radius * v * math.cos(angle),
        center.dy + radius * v * math.sin(angle),
      );
      if (i == 0) {
        dataPath.moveTo(pt.dx, pt.dy);
      } else {
        dataPath.lineTo(pt.dx, pt.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(dataPath, Paint()..color = const Color(0x668364F4));
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = const Color(0xFF7C5CFA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant PentagonRadarChartPainter oldDelegate) => true;
}
