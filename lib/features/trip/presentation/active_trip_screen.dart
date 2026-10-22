import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../destination/domain/destination.dart';
import '../../map/presentation/trip_map_widget.dart';
import '../../map/provider/user_location_provider.dart';
import '../domain/trip_state.dart';
import '../provider/trip_providers.dart';

/// Google Maps-styled Active Trip Navigation Screen featuring edge-to-edge map,
/// top green turn/alert banner, pulsing user puck, and bottom navigation metrics card.
class ActiveTripScreen extends ConsumerStatefulWidget {
  final Destination destination;
  final double alertRadius;

  const ActiveTripScreen({
    super.key,
    required this.destination,
    required this.alertRadius,
  });

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tripState = ref.read(tripNotifierProvider);
      if (tripState.status == TripStatus.idle ||
          tripState.destination.id != widget.destination.id) {
        ref.read(tripNotifierProvider.notifier).startTrip(
              destination: widget.destination,
              alertRadius: widget.alertRadius,
            );
      }
    });
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Exit Navigation?'),
        content: const Text(
          'Background GPS tracking and destination alarms will be stopped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Stay in Journey'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.googleRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(tripNotifierProvider.notifier).cancelTrip();
              context.go('/');
            },
            child: const Text('Exit Navigation'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripNotifierProvider);
    final userFix = ref.watch(userLocationNotifierProvider);

    // Auto-navigate to alarm screen if ringing or overshoot
    ref.listen<TripModel>(tripNotifierProvider, (previous, next) {
      if ((next.status == TripStatus.alarmRinging ||
              next.status == TripStatus.missedOvershoot) &&
          (previous?.status != TripStatus.alarmRinging &&
              previous?.status != TripStatus.missedOvershoot)) {
        context.push(
          '/alarm',
          extra: {
            'title': next.isOvershootDetected
                ? 'Missed Stop Alert!'
                : 'Wake Up! Approaching Stop',
            'subtitle': next.isOvershootDetected
                ? 'You have passed ${next.destination.name}!'
                : 'You are within ${_formatDistance(next.alertRadiusMeters)} of ${next.destination.name}.',
          },
        );
      }
    });

    final destinationLatLng = LatLng(
      trip.destination.latitude,
      trip.destination.longitude,
    );

    // Effective real-time user location
    final effectiveUserLoc = trip.lastFix != null
        ? LatLng(trip.lastFix!.latitude, trip.lastFix!.longitude)
        : (userFix != null
            ? LatLng(userFix.latitude, userFix.longitude)
            : null);

    final isPaused = trip.status == TripStatus.paused;
    final isSnoozed = trip.status == TripStatus.snoozed;

    // Remaining distance until alarm threshold triggers
    final distanceToAlarm = (trip.distanceToDestinationMeters - trip.alertRadiusMeters).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. FULL-SCREEN INTERACTIVE GOOGLE MAP
          Positioned.fill(
            child: TripMapWidget(
              mapController: _mapController,
              userLocation: effectiveUserLoc,
              userAccuracy: trip.lastFix?.accuracy ?? userFix?.accuracy,
              userHeading: trip.lastFix?.bearing ?? userFix?.bearing,
              destinationLocation: destinationLatLng,
              alertRadiusMeters: trip.alertRadiusMeters,
              isInteractive: true,
              showRouteLine: true,
              routePoints: trip.routeCoordinates
                  ?.map((p) => LatLng(p.latitude, p.longitude))
                  .toList(),
              onMyLocationPressed: () {
                if (effectiveUserLoc != null) {
                  _mapController.move(effectiveUserLoc, 16.0);
                }
              },
            ),
          ),

          // 2. TOP GOOGLE MAPS NAVIGATION BANNER (EMERALD GREEN)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPaused
                      ? AppColors.surface
                      : (isSnoozed ? AppColors.brandBlack : AppColors.brandRed),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33181818),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isPaused
                                ? 'Tracking Paused'
                                : (isSnoozed
                                    ? 'Alarm Snoozed (3 mins)'
                                    : (distanceToAlarm > 0
                                        ? 'Alarm in ${_formatDistance(distanceToAlarm)}'
                                        : 'Entering Alarm Radius!')),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Wake up at ${_formatDistance(trip.alertRadiusMeters)} before ${trip.destination.name}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: _showCancelDialog,
                      tooltip: 'Exit Navigation',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. GPS SIGNAL WARNING BANNER (IF DEGRADED)
          if (trip.isGpsDegraded)
            Positioned(
              top: 96,
              left: 12,
              right: 12,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.googleYellow.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.satellite_alt_rounded, color: Colors.black87, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'GPS signal delayed. Searching for satellites...',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. BOTTOM GOOGLE MAPS NAVIGATION CARD
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ETA & Remaining Distance Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          trip.estimatedSecondsRemaining != null
                              ? _formatEta(trip.estimatedSecondsRemaining!)
                              : '-- min',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandRed,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '•  ${_formatDistance(trip.distanceToDestinationMeters)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${trip.currentSpeedKmh.toStringAsFixed(0)} km/h',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Linear Journey Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: trip.progressFraction,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.brandRed,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Controls: Pause/Resume, Snooze, Exit
                    Row(
                      children: [
                        // Red Exit Circle Button
                        FloatingActionButton.small(
                          heroTag: 'exitNavBtn',
                          elevation: 2,
                          backgroundColor: AppColors.surfaceVariant,
                          foregroundColor: AppColors.googleRed,
                          onPressed: _showCancelDialog,
                          child: const Icon(Icons.close_rounded, size: 22),
                        ),
                        const SizedBox(width: 12),

                        // Pause / Resume Button
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.cardBorder),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: Icon(
                              isPaused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              size: 20,
                            ),
                            label: Text(
                              isPaused ? 'Resume Journey' : 'Pause Tracking',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () {
                              if (isPaused) {
                                ref.read(tripNotifierProvider.notifier).resumeTrip();
                              } else {
                                ref.read(tripNotifierProvider.notifier).pauseTrip();
                              }
                            },
                          ),
                        ),

                        // Snooze Button (if active)
                        if (!isPaused) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              isSnoozed ? Icons.snooze_rounded : Icons.bedtime_outlined,
                              color: isSnoozed
                                  ? AppColors.googleBlueLight
                                  : AppColors.textSecondary,
                            ),
                            tooltip: 'Snooze 3 min',
                            onPressed: () {
                              ref.read(tripNotifierProvider.notifier).snoozeAlarm();
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toInt()} m';
  }

  String _formatEta(int seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMin = minutes % 60;
    return '${hours}h ${remainingMin}m';
  }
}
