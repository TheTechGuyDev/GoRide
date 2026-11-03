import 'package:flutter/material.dart';
import 'package:goride_core/goride_core.dart';

import '../../features/driving/driver_controller.dart';

/// The rider's photo, or the first letter of their name.
class RiderAvatar extends StatelessWidget {
  const RiderAvatar({super.key, required this.request, this.radius = 24});

  final RideRequest request;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final letter = Text(
      request.riderName.isEmpty ? '?' : request.riderName[0].toUpperCase(),
      style: TextStyle(
        fontSize: radius * 0.8,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    );
    final url = request.riderPhotoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryLight,
      child: url == null || url.isEmpty
          ? letter
          : ClipOval(
              child: Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => letter,
              ),
            ),
    );
  }
}
