import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/geocoding_service.dart';
import 'place.dart';

final geocodingServiceProvider = Provider((_) => GeocodingService());

class BookingState {
  const BookingState({this.pickup, this.destination, this.pickupNote = ''});

  /// Null pickup means "Your current location".
  final Place? pickup;
  final Place? destination;

  /// Landmark guidance for the driver, e.g. "Opposite GTBank, blue gate".
  final String pickupNote;

  BookingState copyWith({
    Place? pickup,
    Place? destination,
    String? pickupNote,
  }) {
    return BookingState(
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      pickupNote: pickupNote ?? this.pickupNote,
    );
  }
}

/// The ride being put together. Grows in Step 5 (ride type, fare, payment).
class BookingController extends Notifier<BookingState> {
  @override
  BookingState build() => const BookingState();

  void setPickup(Place p) => state = state.copyWith(pickup: p);

  void setDestination(Place p) {
    state = state.copyWith(destination: p);
    ref.read(recentPlacesProvider.notifier).add(p);
  }

  void setPickupNote(String note) => state = state.copyWith(pickupNote: note);

  void reset() => state = const BookingState();
}

final bookingControllerProvider =
    NotifierProvider<BookingController, BookingState>(BookingController.new);

/// Recent destinations, seeded with popular Lagos spots.
/// Later: read/write the rider's trip history in Supabase.
class RecentPlacesController extends Notifier<List<Place>> {
  @override
  List<Place> build() => const [
    Place(
      id: 'seed-icm',
      name: 'Ikeja City Mall',
      address: 'Obafemi Awolowo Way, Alausa, Ikeja',
      position: LatLng(6.6142, 3.3576),
    ),
    Place(
      id: 'seed-eko',
      name: 'Eko Hotel & Suites',
      address: 'Adetokunbo Ademola St, Victoria Island',
      position: LatLng(6.4262, 3.4290),
    ),
    Place(
      id: 'seed-lcc',
      name: 'Lekki Conservation Centre',
      address: 'Lekki-Epe Expressway, Lekki',
      position: LatLng(6.4418, 3.5363),
    ),
    Place(
      id: 'seed-mma',
      name: 'Murtala Muhammed Airport',
      address: 'Airport Rd, Ikeja',
      position: LatLng(6.5774, 3.3212),
    ),
    Place(
      id: 'seed-unilag',
      name: 'University of Lagos',
      address: 'Akoka, Yaba',
      position: LatLng(6.5158, 3.3896),
    ),
    Place(
      id: 'seed-landmark',
      name: 'Landmark Beach',
      address: 'Water Corporation Dr, Oniru, Victoria Island',
      position: LatLng(6.4227, 3.4472),
    ),
  ];

  void add(Place p) {
    state = [p, ...state.where((e) => e.id != p.id)].take(10).toList();
  }
}

final recentPlacesProvider =
    NotifierProvider<RecentPlacesController, List<Place>>(
      RecentPlacesController.new,
    );

/// Places the rider bookmarked from search results.
class BookmarkedPlacesController extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(Place p) {
    state = state.contains(p.id)
        ? ({...state}..remove(p.id))
        : {...state, p.id};
  }
}

final bookmarkedPlacesProvider =
    NotifierProvider<BookmarkedPlacesController, Set<String>>(
      BookmarkedPlacesController.new,
    );
