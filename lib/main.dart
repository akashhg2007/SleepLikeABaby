import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/destination/data/destination_history_repo.dart';
import 'features/destination/data/nominatim_search_api.dart';
import 'features/trip/data/trip_repository.dart';
import 'features/trip/domain/trip_state.dart';
import 'features/trip/provider/trip_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Immersive system overlay styling matching Brand Identity
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFECE7DE),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize persistent repositories
  final prefs = await SharedPreferences.getInstance();
  final historyRepo = DestinationHistoryRepository(prefs);
  final tripRepo = TripRepository(prefs);
  final searchApi = NominatimSearchApi();

  // Lifecycle Recovery: Detect interrupted active trip
  final activeTrip = tripRepo.getActiveTrip();
  final initialRoute =
      (activeTrip != null &&
          (activeTrip.status == TripStatus.active ||
              activeTrip.status == TripStatus.snoozed ||
              activeTrip.status == TripStatus.alarmRinging))
      ? '/active-trip'
      : '/';

  final router = createAppRouter(
    searchApi: searchApi,
    historyRepo: historyRepo,
    initialLocation: initialRoute,
  );

  runApp(
    ProviderScope(
      overrides: [tripRepositoryProvider.overrideWithValue(tripRepo)],
      child: SleepLikeABabyApp(router: router),
    ),
  );
}

class SleepLikeABabyApp extends StatelessWidget {
  final dynamic router;

  const SleepLikeABabyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SleepLikeABaby',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
