/// All route paths in the driver app.
class Routes {
  // Onboarding and auth
  static const splash = '/';
  static const welcome = '/welcome';
  static const signUp = '/sign-up';
  static const signIn = '/sign-in';
  static const otp = '/otp';

  // Registration
  static const registration = '/register';
  static const regPersonal = '/register/personal';
  static const regVehicle = '/register/vehicle';
  static const regDocuments = '/register/documents';
  static const regDocument = '/register/documents/:type';
  static String regDocumentFor(String type) => '/register/documents/$type';
  static const regPlan = '/register/plan';
  static const regBank = '/register/bank';
  static const regStatus = '/register/status';

  // Tabs
  static const home = '/home';
  static const earnings = '/earnings';
  static const trips = '/trips';
  static const account = '/account';

  // Driving
  static const tripPreferences = '/preferences';
  static const trip = '/trip';
  static const tripChat = '/trip/chat';
  static const cancelTrip = '/trip/cancel';
  static const tripComplete = '/trip/complete';
  static const tripDetails = '/trip-details/:id';
  static String tripDetailsFor(String id) => '/trip-details/$id';

  // Money
  static const wallet = '/wallet';
  static const payout = '/wallet/payout';
  static const settle = '/wallet/settle';
  static const plan = '/plan';
  static const transactions = '/wallet/transactions';

  // Account
  static const profile = '/account/profile';
  static const vehicle = '/account/vehicle';
  static const documents = '/account/documents';
  static const bank = '/account/bank';
  static const ratings = '/account/ratings';
  static const notificationSettings = '/account/notifications';
  static const appearance = '/account/appearance';
  static const help = '/help';
  static const referral = '/invite';
  static const privacyPolicy = '/legal/privacy';
  static const terms = '/legal/terms';
  static const notifications = '/notifications';

  // Safety
  static const emergency = '/emergency';
  static const emergencyContacts = '/emergency-contacts';
}
