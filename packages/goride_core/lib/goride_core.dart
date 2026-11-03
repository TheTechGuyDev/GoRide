/// Code shared by the GoRide rider app, driver app and admin dashboard.
library;

export 'src/config/map_config.dart';
export 'src/location/location_controller.dart';
export 'src/map/map_markers.dart';
export 'src/map/path_utils.dart';
export 'src/models/place.dart';
export 'src/models/ride_types.dart';
export 'src/platform/web_insets.dart';
export 'src/services/geocoding_service.dart';
export 'src/services/payment_gateway.dart';
export 'src/services/routing_service.dart';
export 'src/theme/app_colors.dart';
export 'src/theme/app_theme.dart';
export 'src/theme/theme_controller.dart';
export 'src/utils/dates.dart';
export 'src/utils/money.dart';
export 'src/utils/phone_utils.dart';
export 'src/widgets/app_button.dart';
export 'src/widgets/web_preview_frame.dart';
export 'src/widgets/form_widgets.dart';
export 'src/widgets/settings_widgets.dart';
export 'src/widgets/appearance_screen.dart';
export 'src/models/lagos_places.dart';

export 'src/backend/backend.dart';
export 'src/backend/session.dart';
export 'src/backend/paystack_checkout.dart';
export 'src/backend/push_service.dart';

export 'package:supabase_flutter/supabase_flutter.dart'
    show
        Supabase,
        SupabaseClient,
        AuthException,
        AuthChangeEvent,
        OAuthProvider,
        OtpType,
        PostgrestException,
        RealtimeChannel,
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType,
        Session,
        FileOptions,
        FunctionException,
        User;
