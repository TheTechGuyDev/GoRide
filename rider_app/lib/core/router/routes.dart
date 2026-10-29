class Routes {
  Routes._();

  static const splash = '/';
  static const walkthrough = '/walkthrough';
  static const welcome = '/welcome';
  static const signUp = '/sign-up';
  static const signIn = '/sign-in';
  static const otp = '/otp';
  static const personalInfo = '/personal-info';

  // Bottom-nav tabs
  static const home = '/home';
  static const promos = '/promos';
  static const activity = '/activity';
  static const account = '/account';

  // Booking flow
  static const whereTo = '/where-to';
  static const setPickup = '/set-pickup';
  static const rideOptions = '/ride-options';
  static const paymentMethod = '/payment-method';
  static const applyPromo = '/apply-promo';

  // Live trip
  static const trip = '/trip';
  static const driverInfo = '/trip/driver';
  static const chat = '/trip/chat';
  static const call = '/trip/call';
  static const cancelRide = '/trip/cancel';
  static const rideCanceled = '/ride-canceled';
  static const tripArrived = '/trip-arrived';
  static const rateDriver = '/rate-driver';
  static const tipDriver = '/tip-driver';
  static const feedbackThanks = '/feedback-thanks';
  static const rideDetails = '/ride/:id';
  static String rideDetailsFor(String id) => '/ride/$id';

  // Safety
  static const emergency = '/trip/emergency';
  static const emergencyContacts = '/emergency-contacts';
}
