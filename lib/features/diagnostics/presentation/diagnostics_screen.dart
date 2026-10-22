import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../trip/provider/trip_providers.dart';

/// Diagnostics Screen providing visibility into Location Permissions,
/// Background Tracking status, Battery Optimization exemptions, and GPS Health.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  bool _hasBackgroundPermission = false;
  bool _isBatteryOptimizationIgnored = false;
  bool _isNotificationPermissionGranted = false;
  bool _isLocationServiceEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllDiagnostics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllDiagnostics();
    }
  }

  Future<void> _checkAllDiagnostics() async {
    setState(() => _isLoading = true);

    try {
      final nativeBridge = ref.read(nativeLocationBridgeProvider);
      final perms = await nativeBridge.checkPermissions();
      final isBatteryIgnored = await nativeBridge
          .isBatteryOptimizationIgnored();
      final isGpsServiceOn = await Geolocator.isLocationServiceEnabled();

      if (!mounted) return;
      setState(() {
        _hasLocationPermission = perms['hasLocation'] ?? false;
        _hasBackgroundPermission = perms['hasBackgroundLocation'] ?? false;
        _isNotificationPermissionGranted = perms['hasNotifications'] ?? false;
        _isBatteryOptimizationIgnored = isBatteryIgnored;
        _isLocationServiceEnabled = isGpsServiceOn;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestBatteryExemption() async {
    final nativeBridge = ref.read(nativeLocationBridgeProvider);
    await nativeBridge.requestIgnoreBatteryOptimizations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Diagnostics',
            onPressed: _checkAllDiagnostics,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeroCard(),
                const SizedBox(height: 20),

                const Text(
                  'SYSTEM & HARDWARE HEALTH',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),

                _buildDiagnosticItem(
                  title: 'Device GPS Hardware',
                  subtitle: _isLocationServiceEnabled
                      ? 'Location hardware is enabled and calibrated'
                      : 'GPS is turned OFF in system settings',
                  isHealthy: _isLocationServiceEnabled,
                  icon: Icons.gps_fixed_rounded,
                  actionLabel: _isLocationServiceEnabled ? null : 'Enable GPS',
                  onAction: () async => await Geolocator.openLocationSettings(),
                ),
                const SizedBox(height: 10),

                _buildDiagnosticItem(
                  title: 'Precise Location Permission',
                  subtitle: _hasLocationPermission
                      ? 'High-accuracy GPS access is granted'
                      : 'Precise location permission is missing',
                  isHealthy: _hasLocationPermission,
                  icon: Icons.location_on_rounded,
                  actionLabel: _hasLocationPermission ? null : 'Settings',
                  onAction: () async => await Geolocator.openAppSettings(),
                ),
                const SizedBox(height: 10),

                _buildDiagnosticItem(
                  title: 'Background Location',
                  subtitle: _hasBackgroundPermission
                      ? 'Tracks destination while phone is locked or sleeping'
                      : 'May stop tracking when phone locks',
                  isHealthy: _hasBackgroundPermission,
                  icon: Icons.shield_rounded,
                  actionLabel: _hasBackgroundPermission ? null : 'Authorize',
                  onAction: () async => await Geolocator.openAppSettings(),
                ),
                const SizedBox(height: 10),

                if (Platform.isAndroid) ...[
                  _buildDiagnosticItem(
                    title: 'Battery Optimization Exemption',
                    subtitle: _isBatteryOptimizationIgnored
                        ? 'Exempt from aggressive Android Doze killing'
                        : 'System battery savers may kill alarm in background',
                    isHealthy: _isBatteryOptimizationIgnored,
                    isWarning: !_isBatteryOptimizationIgnored,
                    icon: Icons.battery_alert_rounded,
                    actionLabel: _isBatteryOptimizationIgnored ? null : 'Fix',
                    onAction: _requestBatteryExemption,
                  ),
                  const SizedBox(height: 10),
                ],

                _buildDiagnosticItem(
                  title: 'Alarm Notifications & Audio',
                  subtitle: _isNotificationPermissionGranted
                      ? 'Full-screen heads-up alerts and wake lock active'
                      : 'Lock-screen banners may be blocked',
                  isHealthy: _isNotificationPermissionGranted,
                  icon: Icons.notifications_active_rounded,
                ),

                const SizedBox(height: 24),
                const Text(
                  'TUNNELS & SUBWAY ADVISORY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.secondary,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Underground Rail Warning',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Satellite GPS signals cannot penetrate underground subway tunnels. SleepLikeABaby includes an automated Watchdog that flags signal degradation if GPS is dead for over 90 seconds.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeroCard() {
    final allGood =
        _hasLocationPermission &&
        _hasBackgroundPermission &&
        _isNotificationPermissionGranted &&
        _isLocationServiceEnabled &&
        (!Platform.isAndroid || _isBatteryOptimizationIgnored);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: allGood ? AppColors.heroGradient : AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            allGood ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
            color: Colors.white,
            size: 44,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allGood
                      ? 'Device Ready For Sleep'
                      : 'Calibration Recommended',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  allGood
                      ? 'Background location and audio permissions are fully calibrated for reliable alarms.'
                      : 'Review warnings below to ensure alarms can wake you up through locked screens.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticItem({
    required String title,
    required String subtitle,
    required bool isHealthy,
    bool isWarning = false,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final statusColor = isHealthy
        ? AppColors.primary
        : (isWarning ? AppColors.warningAmber : AppColors.alarmRed);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Icon(
              isHealthy ? Icons.check_circle_rounded : Icons.error_rounded,
              color: statusColor,
              size: 20,
            ),
        ],
      ),
    );
  }
}
