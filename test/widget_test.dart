import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sleep_like_a_baby/app_router.dart';
import 'package:sleep_like_a_baby/features/destination/data/destination_history_repo.dart';
import 'package:sleep_like_a_baby/features/destination/data/nominatim_search_api.dart';
import 'package:sleep_like_a_baby/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App shell loads and displays SleepLikeABaby home screen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final historyRepo = DestinationHistoryRepository(prefs);
    final searchApi = NominatimSearchApi();

    final router = createAppRouter(
      searchApi: searchApi,
      historyRepo: historyRepo,
    );

    await tester.pumpWidget(
      ProviderScope(child: SleepLikeABabyApp(router: router)),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Search Bar and Home Explore Card are visible
    expect(find.text('Search destination...'), findsOneWidget);
    expect(find.text('Sleep Like A Baby'), findsOneWidget);
  });
}
