import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/destination.dart';

/// Repository responsible for persisting recent and favorite destinations.
class DestinationHistoryRepository {
  final SharedPreferences _prefs;

  DestinationHistoryRepository(this._prefs);

  static const int _maxRecents = 15;

  /// Retrieves list of saved and recent destinations.
  List<Destination> getRecentDestinations() {
    final raw = _prefs.getString(AppConstants.keyRecentDestinations);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((item) => Destination.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Adds a destination to the top of recent destinations, deduplicating.
  Future<void> addRecent(Destination destination) async {
    final current = getRecentDestinations();
    final updated = [
      destination.copyWith(lastUsedAt: DateTime.now()),
      ...current.where((d) => d.id != destination.id),
    ];
    if (updated.length > _maxRecents) {
      updated.removeRange(_maxRecents, updated.length);
    }
    final encoded = json.encode(updated.map((d) => d.toJson()).toList());
    await _prefs.setString(AppConstants.keyRecentDestinations, encoded);
  }

  /// Toggles favorite status for a destination.
  Future<void> toggleFavorite(String id) async {
    final current = getRecentDestinations();
    final index = current.indexWhere((d) => d.id == id);
    if (index != -1) {
      final target = current[index];
      current[index] = target.copyWith(isFavorite: !target.isFavorite);
      final encoded = json.encode(current.map((d) => d.toJson()).toList());
      await _prefs.setString(AppConstants.keyRecentDestinations, encoded);
    }
  }

  /// Clears recent history (privacy control).
  Future<void> clearHistory() async {
    await _prefs.remove(AppConstants.keyRecentDestinations);
  }
}
