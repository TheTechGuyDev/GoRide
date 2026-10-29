import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../nearby_cars.dart';

/// Top-down vehicle drawn in code (no image assets needed).
class VehicleMarker extends StatelessWidget {
  const VehicleMarker({super.key, required this.heading, required this.type});

  final double heading;
  final VehicleType type;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: heading / 360,
      duration: const Duration(milliseconds: 600),
      child: Center(
        child: CustomPaint(
          size: type == VehicleType.bike
              ? const Size(14, 30)
              : const Size(22, 42),
          painter: type == VehicleType.bike ? _BikePainter() : _CarPainter(),
        ),
      ),
    );
  }
}

class _CarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final body = Paint()..color = AppColors.primary;
    final dark = Paint()..color = const Color(0xFF1E3A2B);
    final roof = Paint()..color = const Color(0xFF3DDC84);
    final light = Paint()..color = const Color(0xFFFFF3B0);

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w * 0.38),
    );
    canvas.drawRRect(bodyRect.shift(const Offset(1, 2)), shadow);
    canvas.drawRRect(bodyRect, body);

    // Windscreen (front = top)
    final front = Path()
      ..moveTo(w * 0.16, h * 0.30)
      ..quadraticBezierTo(w * 0.5, h * 0.20, w * 0.84, h * 0.30)
      ..lineTo(w * 0.78, h * 0.40)
      ..lineTo(w * 0.22, h * 0.40)
      ..close();
    canvas.drawPath(front, dark);

    // Rear window
    final rear = Path()
      ..moveTo(w * 0.22, h * 0.74)
      ..lineTo(w * 0.78, h * 0.74)
      ..lineTo(w * 0.84, h * 0.82)
      ..quadraticBezierTo(w * 0.5, h * 0.88, w * 0.16, h * 0.82)
      ..close();
    canvas.drawPath(rear, dark);

    // Roof
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.42, w * 0.56, h * 0.30),
        Radius.circular(w * 0.12),
      ),
      roof,
    );

    // Headlights
    canvas.drawCircle(Offset(w * 0.22, h * 0.05), w * 0.08, light);
    canvas.drawCircle(Offset(w * 0.78, h * 0.05), w * 0.08, light);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BikePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final tyre = Paint()..color = const Color(0xFF263238);
    final body = Paint()..color = AppColors.primary;
    final rider = Paint()..color = const Color(0xFF1E3A2B);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.25, 1, w * 0.5, h),
        Radius.circular(w * 0.25),
      ),
      shadow,
    );
    // Wheels
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.32, 0, w * 0.36, h * 0.22),
        Radius.circular(w * 0.18),
      ),
      tyre,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.32, h * 0.78, w * 0.36, h * 0.22),
        Radius.circular(w * 0.18),
      ),
      tyre,
    );
    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.2, h * 0.18, w * 0.6, h * 0.64),
        Radius.circular(w * 0.3),
      ),
      body,
    );
    // Handlebar
    canvas.drawRect(Rect.fromLTWH(0, h * 0.26, w, h * 0.06), tyre);
    // Rider helmet
    canvas.drawCircle(Offset(w / 2, h * 0.5), w * 0.28, rider);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Green pin with the rider's photo (or a person icon).
class UserPinMarker extends StatelessWidget {
  const UserPinMarker({super.key, this.photo});

  final Uint8List? photo;

  static const double width = 64;
  static const double height = 76;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            bottom: 0,
            child: Transform.rotate(
              angle: pi / 4,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: width,
            height: width,
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                backgroundImage: photo != null ? MemoryImage(photo!) : null,
                child: photo == null
                    ? const Icon(Icons.person, color: AppColors.primary)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Expanding rings shown while searching for the rider's location.
class PulseRings extends StatefulWidget {
  const PulseRings({super.key, required this.child, this.size = 260});

  final Widget child;
  final double size;

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++) _ring(((_c.value + i / 3) % 1.0)),
              child!,
            ],
          );
        },
        child: widget.child,
      ),
    );
  }

  Widget _ring(double t) {
    final size = widget.size * (0.3 + 0.7 * t);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.28 * (1 - t)),
      ),
    );
  }
}
