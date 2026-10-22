import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/trip_state.dart';

/// Repository managing local persistent storage of active and interrupted trips.
class TripRepository {
  final SharedPreferences _prefs;

  TripRepository(this._prefs);

  /// Saves the active trip state to disk.
  Future<void> saveActiveTrip(TripModel trip) async {
    final encoded = json.encode(trip.toJson());
    await _prefs.setString(AppConstants.keyActiveTrip, encoded);
  }

  /// Restores active trip state if one exists.
  TripModel? getActiveTrip() {
    final raw = _prefs.getString(AppConstants.keyActiveTrip);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      final trip = TripModel.fromJson(map);
      // If trip was already finished or cancelled, don't restore as active
      if (trip.status == TripStatus.arrived ||
          trip.status == TripStatus.cancelled) {
        return null;
      }
      return trip;
    } catch (_) {
      return null;
    }
  }

  /// Clears active trip state.
  Future<void> clearActiveTrip() async {
    await _prefs.remove(AppConstants.keyActiveTrip);
  }
}
