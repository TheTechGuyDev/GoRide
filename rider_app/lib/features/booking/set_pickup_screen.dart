import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../location/location_controller.dart';
import 'booking_controller.dart';
import 'map_picker_screen.dart';

/// Screen 19: confirm where the driver should pick the rider up.
class SetPickupScreen extends ConsumerWidget {
  const SetPickupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.read(bookingControllerProvider);
    final start =
        booking.pickup?.position ??
        ref.read(locationControllerProvider).position;

    return MapPickerScreen(
      mode: MapPickerMode.pickup,
      initialCenter: start,
      onConfirm: (place) {
        ref.read(bookingControllerProvider.notifier).setPickup(place);
        context.push(Routes.rideOptions);
      },
    );
  }
}
