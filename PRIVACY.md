# Privacy & Local Data Architecture

**SleepLikeABaby** is built on a strict **zero-telemetry, offline-first, local-privacy** philosophy. This document explains how location data, user inputs, and device permissions are handled.

---

## 1. Zero Telemetry & No Analytics
- **No Analytics SDKs**: The app contains zero tracking, advertising, or analytics packages (no Firebase Analytics, no Mixpanel, no Facebook SDK, no advertising identifiers).
- **No User Account Required**: SleepLikeABaby functions without registration, phone numbers, or email addresses.
- **No Cloud Sync of Travel History**: Your destinations, commute routines, departure times, and routes are stored purely on your local device.

---

## 2. Location Data Handling
- **Transient Memory Processing**: During an active journey, GPS fixes (latitude, longitude, speed, bearing, accuracy) are evaluated strictly in device RAM to calculate distance to your target stop.
- **No Route Logging**: The app does **not** persist or record a trail of your past location coordinates or travel breadcrumbs.
- **Foreground Service Transparency**:
  - **Android**: While active, a visible ongoing notification is permanently displayed in your status bar indicating that location tracking is running.
  - **iOS**: A prominent blue location indicator pill is displayed in the status bar (`showsBackgroundLocationIndicator = true`) whenever background tracking is active.
- **Immediate Termination**: As soon as you tap "I am Awake", "Cancel Journey", or arrive at your stop, native location tracking stops immediately and background services are shut down.

---

## 3. Geocoding & Search
- Place searches use **Photon (Komoot OpenStreetMap)** with **Nominatim** fallback over encrypted HTTPS (TLS 1.3).
- Search queries contain only the keyword you type (e.g. "Grand Central Terminal") and optional coarse proximity coordinates to prioritize nearby stations.
- If you are offline, SleepLikeABaby falls back to locally embedded transit presets so you can set alarms even without mobile internet.

---

## 4. User Controls & Data Erasure
- **Clear Trip History**: At any time, you can open **Preferences -> Clear All Search & Trip History** to wipe all cached destinations and saved recents from the device storage.
- **Uninstall Cleans All**: Uninstalling the app completely purges all local databases and `SharedPreferences` keys.
