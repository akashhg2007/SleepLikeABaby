# 🚆 SleepLikeABaby — Production Destination Alarm App

A production-grade, privacy-respecting cross-platform destination alarm app built with **Flutter**, **Dart**, **Native Android Kotlin**, and **Native iOS Swift**.

Designed specifically for train, bus, and road commuters who sleep or lock their phones during travel and need a reliable wake-up alarm before reaching their destination stop.

---

## 📸 Key Features

1. **Precision Geofencing & Map Picker**: Interactive OpenStreetMap interface with live geofence visualization, tap-to-pin destination selection, and reverse geocoding.
2. **Debounced Search**: Fast place lookup using Photon (Komoot OSM) and Nominatim with curated offline transit hub fallbacks.
3. **Native Background Tracking**:
   - **Android**: Dedicated Kotlin `ForegroundService` with `FOREGROUND_SERVICE_LOCATION`, `PARTIAL_WAKE_LOCK`, and ongoing distance updates.
   - **iOS**: Swift `CLLocationManager` with `allowsBackgroundLocationUpdates`, `showsBackgroundLocationIndicator`, and background audio session.
4. **Speed-Aware Early Alerts**: High-speed train/express bus detection calculating dynamic ETA so sleeping commuters get adequate advance warning at 100+ km/h.
5. **Missed Stop / Overshoot Detection**: Detects if a commuter has passed their destination and sounds an emergency alarm.
6. **GPS Watchdog**: Automatically detects signal loss in tunnels or underground subways (>90 seconds) and warns the commuter.
7. **Crash & Reboot Recovery**: Persistent state machine in `SharedPreferences` with `BOOT_COMPLETED` receiver to restore interrupted journeys.
8. **High-Urgency Lockscreen Alarm**: Looped audio, rhythmic vibration pulses, full-screen lockscreen intent, and 3-minute snooze.
9. **Zero Telemetry**: No third-party analytics or cloud tracking. All location fixes are processed ephemerally on-device.

---

## 🏛️ System Architecture

```text
lib/
├── core/
│   ├── constants/               # Alert radii presets, channel names, thresholds
│   ├── errors/                  # Strongly typed AppException hierarchy
│   ├── native_bridge/           # MethodChannel & EventChannel interfaces
│   ├── theme/                   # High-contrast OLED dark theme & semantic colors
│   └── utils/                   # Haversine distance, Azimuth bearing, GPS filtering, ETA
├── features/
│   ├── alarm/                   # Looped audio, haptic pulses, lockscreen notification
│   ├── destination/             # Domain model, Photon/Nominatim search API, history repo
│   ├── diagnostics/             # Live permissions inspector & battery optimization intent
│   ├── map/                     # FlutterMap OSM tile widget, geofence, accuracy circles
│   ├── settings/                # Imperial/Metric units, speed buffer, data clearance
│   └── trip/                    # Riverpod 3 TripNotifier state machine & ActiveTrip dashboard
├── app_router.dart              # GoRouter navigation & deep linking
└── main.dart                    # App initialization, Riverpod Scope, lifecycle recovery
```

---

## 📱 Platform Configuration & Native Setup

### Android Setup (API 26+)
- **Foreground Service Type**: Declared with `android:foregroundServiceType="location"`.
- **Permissions Declared**:
  - `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`
  - `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` (Android 14+ / API 34 compliance)
  - `POST_NOTIFICATIONS` (Android 13+ runtime permission)
  - `USE_FULL_SCREEN_INTENT`, `WAKE_LOCK`, `VIBRATE`
  - `RECEIVE_BOOT_COMPLETED`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
- **OEM Battery Aggression (Samsung, Xiaomi, Huawei, OnePlus)**:
  - Users are guided through **System Diagnostics** to grant Battery Optimization exemption (`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`).
- **Core Library Desugaring**: Enabled in `android/app/build.gradle.kts` via `desugar_jdk_libs:2.1.4`.

### iOS Setup (iOS 15+)
- **Background Modes**: Configured in `ios/Runner/Info.plist`:
  - `location` (continuous background location updates)
  - `audio` (background audio session to sound alarms through lock screen)
- **Privacy Strings**:
  - `NSLocationWhenInUseUsageDescription`
  - `NSLocationAlwaysAndWhenInUseUsageDescription`
  - `NSLocationAlwaysUsageDescription`
- **Honest Platform Limitations**:
  - If the user force-closes the app from the iOS App Switcher, iOS terminates background execution completely. The app instructs users to keep the app in the background.
  - Standard local notifications respect the hardware silent switch; therefore, continuous background tracking uses an active `AVAudioSessionCategoryPlayback` to guarantee audible alerts.

---

## 🧪 Testing & Verification

Run the full suite of unit tests, geodetic math tests, state machine tests, and widget tests:

```bash
# Run all tests
flutter test

# Run static analysis
flutter analyze

# Build Android Debug APK
flutter build apk --debug
```

### Test Coverage Highlights
- `test/unit/distance_calculator_test.dart`: Haversine precision (known coordinates Grand Central to Penn Station NYC), Azimuth bearing, and overshoot detection edge cases.
- `test/unit/gps_filter_test.dart`: Rejection of poor accuracy fixes (>75m), rejection of teleport speed jumps (>360 km/h), acceptance of valid transit fixes.
- `test/unit/trip_state_machine_test.dart`: State transitions (`idle` -> `active` -> `alarmRinging` -> `snoozed` -> `arrived`), speed-aware early alerts, overshoot triggers.
- `test/unit/lifecycle_recovery_test.dart`: SharedPreferences state persistence across app kills, ignoring finished trips, and corrupt storage resilience.
- `test/widget_test.dart`: App shell bootstrap, theme application, and GoRouter initial route rendering.

---

## 🔒 Privacy & License

See [PRIVACY.md](file:///c:/Users/admin/OneDrive/Documents/SleepLIkeABaby/PRIVACY.md) for full data disclosure.
License: MIT.
