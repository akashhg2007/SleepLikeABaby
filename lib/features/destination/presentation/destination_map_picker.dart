import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../map/presentation/trip_map_widget.dart';
import '../data/nominatim_search_api.dart';
import '../domain/destination.dart';

/// Fullscreen interactive map picker to tap and place destination pin,
/// adjust alert radius, and reverse geocode location.
class DestinationMapPicker extends StatefulWidget {
  final LatLng? initialCenter;
  final LatLng? initialSelectedPoint;
  final double initialRadiusMeters;
  final NominatimSearchApi searchApi;

  const DestinationMapPicker({
    super.key,
    this.initialCenter,
    this.initialSelectedPoint,
    this.initialRadiusMeters = AppConstants.defaultAlertRadius,
    required this.searchApi,
  });

  @override
  State<DestinationMapPicker> createState() => _DestinationMapPickerState();
}

class _DestinationMapPickerState extends State<DestinationMapPicker> {
  LatLng? _selectedPoint;
  late double _alertRadius;
  bool _isGeocoding = false;
  String _locationName = 'Tap on the map to place destination';
  String _locationAddress = 'Choose where you want to be awakened';
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _alertRadius = widget.initialRadiusMeters;
    _selectedPoint = widget.initialSelectedPoint;

    if (_selectedPoint != null) {
      _reverseGeocodePoint(_selectedPoint!);
    }
  }

  Future<void> _reverseGeocodePoint(LatLng point) async {
    setState(() {
      _isGeocoding = true;
      _selectedPoint = point;
    });

    try {
      final dest = await widget.searchApi.reverseGeocode(
        point.latitude,
        point.longitude,
      );
      if (!mounted) return;
      setState(() {
        _locationName = dest.name;
        _locationAddress = dest.displayName;
        _isGeocoding = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationName = 'Selected Destination';
        _locationAddress =
            '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        _isGeocoding = false;
      });
    }
  }

  void _onMapTapped(LatLng point) {
    _reverseGeocodePoint(point);
  }

  void _confirmSelection() {
    if (_selectedPoint == null) return;
    final pt = _selectedPoint!;
    final destination = Destination(
      id: 'custom_${pt.latitude.toStringAsFixed(4)}_${pt.longitude.toStringAsFixed(4)}',
      name: _locationName,
      displayName: _locationAddress,
      latitude: pt.latitude,
      longitude: pt.longitude,
    );

    Navigator.of(
      context,
    ).pop({'destination': destination, 'alertRadius': _alertRadius});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // The Interactive Map
          TripMapWidget(
            mapController: _mapController,
            userLocation: widget.initialCenter,
            destinationLocation: _selectedPoint,
            alertRadiusMeters: _alertRadius,
            onMapTap: _onMapTapped,
            isInteractive: true,
          ),

          // Top Header Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Material(
                  color: AppColors.surface.withValues(alpha: 0.9),
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.cardBorder),
                  ),
                  elevation: 4,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.touch_app_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Tap anywhere on map',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Control Card: Destination Info, Radius Selector & Confirm Button
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Title & Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.alarmRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.flag_rounded,
                          color: AppColors.alarmRed,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isGeocoding)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            else
                              Text(
                                _locationName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              _locationAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Alert Radius Selector Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Alert Radius (Wake up before)',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatDistance(_alertRadius),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Radius Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: AppConstants.alertRadiusPresets.map((r) {
                        final isSelected = (_alertRadius - r).abs() < 1.0;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_formatDistance(r)),
                            selected: isSelected,
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
                  const SizedBox(height: 20),

                  // Confirm Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPoint != null
                          ? AppColors.googleBlue
                          : AppColors.surfaceVariant,
                      foregroundColor: _selectedPoint != null
                          ? Colors.white
                          : AppColors.textMuted,
                      minimumSize: const Size(double.infinity, 50),
                      elevation: _selectedPoint != null ? 3 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      _selectedPoint != null
                          ? 'Set as Destination'
                          : 'Tap Map to Choose Destination',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _selectedPoint != null ? _confirmSelection : null,
                  ),
                ],
              ),
            ),
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
