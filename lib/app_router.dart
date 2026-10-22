import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'features/alarm/presentation/alarm_screen.dart';
import 'features/destination/data/destination_history_repo.dart';
import 'features/destination/data/nominatim_search_api.dart';
import 'features/destination/domain/destination.dart';
import 'features/destination/presentation/destination_map_picker.dart';
import 'features/diagnostics/presentation/diagnostics_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/trip/presentation/active_trip_screen.dart';
import 'features/trip/presentation/home_screen.dart';

/// App router configuration using GoRouter.
GoRouter createAppRouter({
  required NominatimSearchApi searchApi,
  required DestinationHistoryRepository historyRepo,
  String initialLocation = '/',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) =>
            HomeScreen(searchApi: searchApi, historyRepo: historyRepo),
      ),
      GoRoute(
        path: '/map-picker',
        name: 'map_picker',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return DestinationMapPicker(
            searchApi: searchApi,
            initialRadiusMeters:
                extra?['alertRadius'] as double? ??
                AppConstants.defaultAlertRadius,
          );
        },
      ),
      GoRoute(
        path: '/active-trip',
        name: 'active_trip',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final destination =
              extra?['destination'] as Destination? ??
              const Destination(
                id: 'fallback',
                name: 'Destination',
                displayName: 'En route',
                latitude: 40.7527,
                longitude: -73.9772,
              );
          final alertRadius =
              extra?['alertRadius'] as double? ??
              AppConstants.defaultAlertRadius;

          return ActiveTripScreen(
            destination: destination,
            alertRadius: alertRadius,
          );
        },
      ),
      GoRoute(
        path: '/alarm',
        name: 'alarm',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AlarmScreen(
            title: extra?['title'] as String? ?? 'Approaching Destination!',
            subtitle:
                extra?['subtitle'] as String? ??
                'Time to wake up and get ready to exit.',
          );
        },
      ),
      GoRoute(
        path: '/diagnostics',
        name: 'diagnostics',
        builder: (context, state) => const DiagnosticsScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => SettingsScreen(historyRepo: historyRepo),
      ),
    ],
  );
}
