import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../destination/data/destination_history_repo.dart';
import '../../destination/data/nominatim_search_api.dart';
import '../../destination/domain/destination.dart';
import '../../destination/presentation/destination_map_picker.dart';
import '../../destination/presentation/destination_search_sheet.dart';
import '../../map/presentation/trip_map_widget.dart';
import '../../map/provider/user_location_provider.dart';
import '../provider/trip_providers.dart';

/// Authentic Google Maps-styled Home Screen with full-screen interactive map,
/// floating search capsule, quick category chips, live GPS tracking puck,
/// and dynamic place card with wake-up geofence controls.
class HomeScreen extends ConsumerStatefulWidget {
  final NominatimSearchApi searchApi;
  final DestinationHistoryRepository historyRepo;

  const HomeScreen({
    super.key,
    required this.searchApi,
    required this.historyRepo,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MapController _mapController = MapController();
  Destination? _selectedDestination;
  double _alertRadius = AppConstants.defaultAlertRadius;
  bool _isReverseGeocoding = false;
  List<LatLng>? _previewRoutePoints;
  String? _estimatedDurationText;
  double? _roadDistanceMeters;

  @override
  void initState() {
    super.initState();
  }

  void _openSearchSheet({String? initialQuery}) async {
    final liveUserLoc = ref.read(userLatLngProvider);

    final result = await showModalBottomSheet<Destination>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DestinationSearchSheet(
        searchApi: widget.searchApi,
        historyRepo: widget.historyRepo,
        userLocation: liveUserLoc,
        onOpenMapPicker: _openMapPicker,
      ),
    );

    if (result != null) {
      _onDestinationSelected(result);
    }
  }

  void _openMapPicker() async {
    final liveUserLoc = ref.read(userLatLngProvider);

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => DestinationMapPicker(
          initialCenter: _selectedDestination != null
              ? LatLng(
                  _selectedDestination!.latitude,
                  _selectedDestination!.longitude,
                )
              : liveUserLoc,
          initialSelectedPoint: _selectedDestination != null
              ? LatLng(
                  _selectedDestination!.latitude,
                  _selectedDestination!.longitude,
                )
              : null,
          initialRadiusMeters: _alertRadius,
          searchApi: widget.searchApi,
        ),
      ),
    );

    if (result != null && mounted) {
      final dest = result['destination'] as Destination;
      final rad = result['alertRadius'] as double;
      setState(() {
        _selectedDestination = dest;
        _alertRadius = rad;
        _previewRoutePoints = null;
        _estimatedDurationText = null;
        _roadDistanceMeters = null;
      });
      _flyToDestination(dest);
      _fetchRoutePreview(dest);
    }
  }

  void _onDestinationSelected(Destination dest) {
    setState(() {
      _selectedDestination = dest;
      _previewRoutePoints = null;
      _estimatedDurationText = null;
      _roadDistanceMeters = null;
    });
    _flyToDestination(dest);
    _fetchRoutePreview(dest);
  }

  void _fetchRoutePreview(Destination dest) async {
    final liveUserLoc = ref.read(userLatLngProvider);
    if (liveUserLoc == null) return;
    try {
      final routing = ref.read(routingServiceProvider);
      final res = await routing.fetchRoute(
        originLat: liveUserLoc.latitude,
        originLng: liveUserLoc.longitude,
        destLat: dest.latitude,
        destLng: dest.longitude,
      );
      if (mounted && _selectedDestination?.id == dest.id) {
        setState(() {
          _previewRoutePoints = res.points
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();
          _roadDistanceMeters = res.distanceMeters;
          _estimatedDurationText = res.formattedDuration;
        });
      }
    } catch (_) {}
  }

  void _flyToDestination(Destination dest) {
    final destLatLng = LatLng(dest.latitude, dest.longitude);
    final liveUserLoc = ref.read(userLatLngProvider);

    if (liveUserLoc != null) {
      final bounds = LatLngBounds.fromPoints([liveUserLoc, destLatLng]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(
            left: 50.0,
            right: 50.0,
            top: 130.0,
            bottom: 300.0,
          ),
        ),
      );
    } else {
      _mapController.move(destLatLng, 15.0);
    }
  }

  Future<void> _onMapTapped(LatLng point) async {
    setState(() => _isReverseGeocoding = true);
    try {
      final dest = await widget.searchApi.reverseGeocode(
        point.latitude,
        point.longitude,
      );
      if (mounted) {
        setState(() {
          _selectedDestination = dest;
          _isReverseGeocoding = false;
          _previewRoutePoints = null;
          _estimatedDurationText = null;
          _roadDistanceMeters = null;
        });
        _fetchRoutePreview(dest);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isReverseGeocoding = false);
      }
    }
  }

  void _startJourney() {
    if (_selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a destination first'),
          backgroundColor: AppColors.alarmRed,
        ),
      );
      return;
    }

    context.push(
      '/active-trip',
      extra: {
        'destination': _selectedDestination,
        'alertRadius': _alertRadius,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userFix = ref.watch(userLocationNotifierProvider);
    final userLatLng = ref.watch(userLatLngProvider);

    final destLatLng = _selectedDestination != null
        ? LatLng(
            _selectedDestination!.latitude,
            _selectedDestination!.longitude,
          )
        : null;

    double? distanceMeters;
    if (userLatLng != null && destLatLng != null) {
      distanceMeters = DistanceCalculator.haversineDistanceMeters(
        userLatLng.latitude,
        userLatLng.longitude,
        destLatLng.latitude,
        destLatLng.longitude,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. FULL-SCREEN INTERACTIVE GOOGLE MAP
          Positioned.fill(
            child: TripMapWidget(
              mapController: _mapController,
              userLocation: userLatLng,
              userAccuracy: userFix?.accuracy,
              userHeading: userFix?.bearing,
              destinationLocation: destLatLng,
              alertRadiusMeters: _alertRadius,
              isInteractive: true,
              routePoints: _previewRoutePoints,
              onMapTap: _onMapTapped,
              onMyLocationPressed: () {
                ref.read(userLocationNotifierProvider.notifier).refreshLocation();
              },
            ),
          ),

          // 2. FLOATING TOP GOOGLE MAPS SEARCH HEADER
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGoogleSearchBar(),
                  _buildQuickCategoryChips(),
                ],
              ),
            ),
          ),

          // 3. REVERSE GEOCODING LOADING INDICATOR
          if (_isReverseGeocoding)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.googleBlue,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Locating selected point...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. FLOATING BOTTOM GOOGLE MAPS PLACE / WAKE-UP CARD
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: _selectedDestination != null
                  ? _buildSelectedDestinationCard(distanceMeters)
                  : _buildExploreCard(),
            ),
          ),
        ],
      ),
    );
  }

  /// Authentic Google Maps floating search bar capsule
  Widget _buildGoogleSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => _openSearchSheet(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedDestination != null
                            ? _selectedDestination!.name
                            : 'Search destination...',
                        style: TextStyle(
                          color: _selectedDestination != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: _selectedDestination != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_selectedDestination != null)
                        Text(
                          _selectedDestination!.displayName,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (_selectedDestination != null) ...[
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _selectedDestination = null);
                    },
                    tooltip: 'Clear destination',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                  const SizedBox(width: 4),
                ],
                IconButton(
                  icon: const Icon(
                    Icons.map_outlined,
                    color: AppColors.googleBlue,
                    size: 20,
                  ),
                  onPressed: _openMapPicker,
                  tooltip: 'Map picker',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                ),
                const SizedBox(width: 4),
                // Diagnostics Shield Avatar
                GestureDetector(
                  onTap: () => context.push('/diagnostics'),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.googleGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.googleGreen.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: AppColors.googleGreen,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Google Maps horizontal quick category chips
  Widget _buildQuickCategoryChips() {
    final categories = [
      {'icon': Icons.train_outlined, 'label': 'Metro / Train', 'query': 'Station'},
      {'icon': Icons.home_outlined, 'label': 'Home', 'query': 'Home'},
      {'icon': Icons.work_outline_rounded, 'label': 'Work', 'query': 'Office'},
      {'icon': Icons.flight_takeoff_rounded, 'label': 'Airport', 'query': 'Airport'},
      {'icon': Icons.touch_app_outlined, 'label': 'Pick on Map', 'query': null},
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = categories[index];
          return ActionChip(
            avatar: Icon(
              item['icon'] as IconData,
              size: 16,
              color: AppColors.textPrimary,
            ),
            label: Text(
              item['label'] as String,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: AppColors.surface.withValues(alpha: 0.95),
            side: const BorderSide(color: AppColors.cardBorder, width: 0.8),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onPressed: () {
              if (item['query'] == null) {
                _openMapPicker();
              } else {
                _openSearchSheet(initialQuery: item['query'] as String);
              }
            },
          );
        },
      ),
    );
  }

  /// Minimal Google Maps card when exploring / no destination selected
  Widget _buildExploreCard() {
    final recents = widget.historyRepo.getRecentDestinations();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Sleep Like A Baby',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Settings'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Select a destination stop. The app tracks your GPS in the background and rings an urgent alarm before you arrive.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          if (recents.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recents.take(4).length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final recent = recents[index];
                  return ActionChip(
                    avatar: const Icon(
                      Icons.history_rounded,
                      size: 15,
                      color: AppColors.googleBlue,
                    ),
                    label: Text(
                      recent.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: AppColors.surfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onPressed: () => _onDestinationSelected(recent),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Full Google Maps destination & wake-up distance control card
  Widget _buildSelectedDestinationCard(double? distanceMeters) {
    return Container(
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Destination Title & Distance Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.googleRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.googleRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedDestination!.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedDestination!.displayName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (distanceMeters != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.googleBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatDistance(_roadDistanceMeters ?? distanceMeters),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.googleBlueLight,
                        ),
                      ),
                    ),
                    if (_estimatedDurationText != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '~$_estimatedDurationText',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.googleGreen,
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Wake Up Geofence Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 16,
                    color: AppColors.googleBlue,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Wake Up Radius',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                _formatDistance(_alertRadius),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.googleBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Google Maps Radius Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: AppConstants.alertRadiusPresets.map((r) {
                final isSelected = (_alertRadius - r).abs() < 1.0;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: Colors.white,
                          )
                        : null,
                    label: Text(_formatDistance(r)),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.googleBlue,
                    backgroundColor: AppColors.surfaceVariant,
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.googleBlue
                          : AppColors.cardBorder,
                      width: 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _alertRadius = r);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Big Brand Navigation Action Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              elevation: 4,
              shadowColor: AppColors.brandRed.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            icon: const Icon(Icons.alarm_on_rounded, size: 22),
            label: const Text(
              'Start Sleep Journey',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            onPressed: _startJourney,
          ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(meters % 1000 == 0 ? 0 : 1)} km';
    }
    return '${meters.toInt()} m';
  }
}
