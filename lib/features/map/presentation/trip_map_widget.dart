import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';

enum MapTileStyle {
  cartoVoyager(
    'Clean OSM (Voyager)',
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
    ['a', 'b', 'c', 'd'],
  ),
  standard(
    'OpenStreetMap',
    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    ['a', 'b', 'c'],
  ),
  cartoDark(
    'Dark Mode (OSM)',
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
    ['a', 'b', 'c', 'd'],
  ),
  hybrid(
    'Satellite',
    'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
    [],
  );

  final String label;
  final String urlTemplate;
  final List<String> subdomains;
  const MapTileStyle(this.label, this.urlTemplate, this.subdomains);
}

/// OpenStreetMap & MapLibre-styled interactive map featuring edge-to-edge canvas,
/// authentic pulsing location puck with heading beam, destination pin,
/// route polyline, OSM attribution, and floating map controls.
class TripMapWidget extends StatefulWidget {
  final LatLng? userLocation;
  final double? userAccuracy;
  final double? userHeading;
  final LatLng? destinationLocation;
  final double alertRadiusMeters;
  final void Function(LatLng point)? onMapTap;
  final bool isInteractive;
  final MapController? mapController;
  final VoidCallback? onMyLocationPressed;
  final bool showRouteLine;
  final List<LatLng>? routePoints;

  const TripMapWidget({
    super.key,
    this.userLocation,
    this.userAccuracy,
    this.userHeading,
    this.destinationLocation,
    this.alertRadiusMeters = 1000.0,
    this.onMapTap,
    this.isInteractive = true,
    this.mapController,
    this.onMyLocationPressed,
    this.showRouteLine = true,
    this.routePoints,
  });

  @override
  State<TripMapWidget> createState() => _TripMapWidgetState();
}

class _TripMapWidgetState extends State<TripMapWidget>
    with TickerProviderStateMixin {
  late final MapController _controller;
  MapTileStyle _tileStyle = MapTileStyle.cartoVoyager;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _hasInitialAnimatedToUser = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.mapController ?? MapController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.userLocation != null && widget.destinationLocation == null) {
      _hasInitialAnimatedToUser = true;
    }
  }

  @override
  void didUpdateWidget(covariant TripMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Smoothly glide to user when location is acquired
    if (widget.userLocation != null &&
        widget.destinationLocation == null &&
        !_hasInitialAnimatedToUser) {
      _hasInitialAnimatedToUser = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.userLocation != null) {
          _animatedMapMove(widget.userLocation!, 16.0);
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// 60 FPS silky smooth gliding camera movement
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final camera = _controller.camera;
    final latTween = Tween<double>(
      begin: camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: camera.zoom,
      end: destZoom,
    );

    final moveController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );

    final animation = CurvedAnimation(
      parent: moveController,
      curve: Curves.fastOutSlowIn,
    );

    moveController.addListener(() {
      _controller.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        moveController.dispose();
      }
    });

    moveController.forward();
  }

  void _recenterOnUser() {
    if (widget.userLocation != null) {
      _animatedMapMove(widget.userLocation!, 16.5);
    }
    widget.onMyLocationPressed?.call();
  }

  void _fitBounds() {
    if (widget.userLocation != null && widget.destinationLocation != null) {
      final bounds = LatLngBounds.fromPoints([
        widget.userLocation!,
        widget.destinationLocation!,
      ]);
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(
            left: 50.0,
            right: 50.0,
            top: 120.0,
            bottom: 260.0, // avoid bottom sheet overlap
          ),
        ),
      );
    } else if (widget.destinationLocation != null) {
      _animatedMapMove(widget.destinationLocation!, 15.0);
    } else if (widget.userLocation != null) {
      _animatedMapMove(widget.userLocation!, 16.0);
    }
  }

  void _zoomIn() {
    final currentZoom = _controller.camera.zoom;
    _animatedMapMove(_controller.camera.center, (currentZoom + 1).clamp(3.0, 19.0));
  }

  void _zoomOut() {
    final currentZoom = _controller.camera.zoom;
    _animatedMapMove(_controller.camera.center, (currentZoom - 1).clamp(3.0, 19.0));
  }

  void _resetNorth() {
    _controller.rotate(0.0);
  }

  void _toggleTileLayer() {
    setState(() {
      final nextIndex = (_tileStyle.index + 1) % MapTileStyle.values.length;
      _tileStyle = MapTileStyle.values[nextIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic starting viewport: Destination -> Live GPS -> Neutral globe
    final LatLng initialCenter;
    final double initialZoom;
    if (widget.destinationLocation != null) {
      initialCenter = widget.destinationLocation!;
      initialZoom = 15.5;
    } else if (widget.userLocation != null) {
      initialCenter = widget.userLocation!;
      initialZoom = 16.0;
    } else {
      initialCenter = const LatLng(0, 0); // Neutral world overview until live GPS fix locks in
      initialZoom = 2.0;
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
              enableMultiFingerGestureRace: true,
            ),
            onTap: widget.isInteractive && widget.onMapTap != null
                ? (tapPosition, point) => widget.onMapTap!(point)
                : null,
          ),
          children: [
            // Ultra-optimized Tile Layer with Multi-Domain Parallelization & Memory Cache
            TileLayer(
              urlTemplate: _tileStyle.urlTemplate,
              subdomains: _tileStyle.subdomains,
              userAgentPackageName: 'com.sleeplikeababy.sleep_like_a_baby',
              maxZoom: 19,
              panBuffer: 1,
              keepBuffer: 5,
              tileDisplay: const TileDisplay.fadeIn(
                duration: Duration(milliseconds: 100),
              ),
              evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
            ),

            // OpenStreetMap Route Polyline connecting user to destination
            if (widget.showRouteLine) ...[
              if (widget.routePoints != null && widget.routePoints!.length >= 2)
                PolylineLayer(
                  polylines: [
                    // Shadow stroke
                    Polyline(
                      points: widget.routePoints!,
                      strokeWidth: 6.5,
                      color: Colors.black26,
                    ),
                    // Solid navigation blue line
                    Polyline(
                      points: widget.routePoints!,
                      strokeWidth: 4.5,
                      color: AppColors.googleRouteBlue,
                    ),
                  ],
                )
              else if (widget.userLocation != null &&
                  widget.destinationLocation != null)
                PolylineLayer(
                  polylines: [
                    // Shadow stroke
                    Polyline(
                      points: [widget.userLocation!, widget.destinationLocation!],
                      strokeWidth: 5.5,
                      color: Colors.black26,
                    ),
                    // Solid navigation line
                    Polyline(
                      points: [widget.userLocation!, widget.destinationLocation!],
                      strokeWidth: 4.0,
                      color: AppColors.googleRouteBlue.withValues(alpha: 0.8),
                    ),
                  ],
                ),
            ],

            // Geofence & GPS Accuracy Circles
            CircleLayer(
              circles: [
                // Destination Geofence Alert Radius
                if (widget.destinationLocation != null)
                  CircleMarker(
                    point: widget.destinationLocation!,
                    radius: widget.alertRadiusMeters,
                    useRadiusInMeter: true,
                    color: AppColors.googleBlue.withValues(alpha: 0.15),
                    borderColor: AppColors.googleBlue,
                    borderStrokeWidth: 2.2,
                  ),

                // Live User Location GPS Accuracy Halo
                if (widget.userLocation != null && widget.userAccuracy != null)
                  CircleMarker(
                    point: widget.userLocation!,
                    radius: widget.userAccuracy!.clamp(8.0, 100.0),
                    useRadiusInMeter: true,
                    color: AppColors.googleBlue.withValues(alpha: 0.10),
                    borderColor: AppColors.googleBlue.withValues(alpha: 0.35),
                    borderStrokeWidth: 1.0,
                  ),
              ],
            ),

            // Markers Layer (Google Red Destination Pin & Pulsing Blue Puck)
            MarkerLayer(
              markers: [
                // Destination Pin
                if (widget.destinationLocation != null)
                  Marker(
                    point: widget.destinationLocation!,
                    width: 44,
                    height: 52,
                    alignment: Alignment.topCenter,
                    child: _buildGoogleDestinationPin(),
                  ),

                // Real-time User Location Puck
                if (widget.userLocation != null)
                  Marker(
                    point: widget.userLocation!,
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: _buildGoogleLocationPuck(),
                  ),
              ],
            ),
          ],
        ),

        // Google Maps Floating Map Action Buttons
        if (widget.isInteractive)
          Positioned(
            right: 14,
            top: 110, // below floating search bar
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFloatingCircleButton(
                  icon: Icons.layers_outlined,
                  tooltip: 'Switch layer (${_tileStyle.label})',
                  onTap: _toggleTileLayer,
                ),
                const SizedBox(height: 10),
                _buildFloatingCircleButton(
                  icon: Icons.explore_outlined,
                  tooltip: 'Reset North',
                  onTap: _resetNorth,
                ),
              ],
            ),
          ),

        if (widget.isInteractive)
          Positioned(
            right: 14,
            bottom: 270, // above bottom sheet
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom Controls Pill
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildZoomButton(
                        icon: Icons.add,
                        tooltip: 'Zoom in',
                        onTap: _zoomIn,
                        isTop: true,
                      ),
                      Container(
                        width: 24,
                        height: 0.8,
                        color: AppColors.cardBorder.withValues(alpha: 0.5),
                      ),
                      _buildZoomButton(
                        icon: Icons.remove,
                        tooltip: 'Zoom out',
                        onTap: _zoomOut,
                        isTop: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Fit bounds button (if both user and destination exist)
                if (widget.userLocation != null &&
                    widget.destinationLocation != null) ...[
                  _buildFloatingCircleButton(
                    icon: Icons.route_rounded,
                    tooltip: 'Fit route',
                    onTap: _fitBounds,
                  ),
                  const SizedBox(height: 14),
                ],

                // Google Maps My Location (Crosshair) Button
                _buildFloatingCircleButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Center on my location',
                  iconColor: widget.userLocation != null
                      ? AppColors.googleBlue
                      : AppColors.textSecondary,
                  onTap: _recenterOnUser,
                ),
              ],
            ),
          ),

        // Mandatory OpenStreetMap Legal Attribution (ODbL Compliance)
        Positioned(
          left: 10,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Brand Alarm Pin matching the user's illustration (Clock merged with Destination Pin)
  Widget _buildGoogleDestinationPin() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Alarm Bells (black arches on top)
            Positioned(
              top: -4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: -0.4,
                    child: Container(
                      width: 9,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.brandBlack,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Transform.rotate(
                    angle: 0.4,
                    child: Container(
                      width: 9,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.brandBlack,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Teardrop Pin Body
            Icon(
              Icons.location_pin,
              color: AppColors.brandRed,
              size: 46,
              shadows: const [
                Shadow(
                  color: Color(0x40181818),
                  blurRadius: 6,
                  offset: Offset(0, 4),
                ),
              ],
            ),

            // White Clock Face with Hands
            Positioned(
              top: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.brandBlack, width: 1.2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Center pivot
                    Container(
                      width: 2.5,
                      height: 2.5,
                      decoration: const BoxDecoration(
                        color: AppColors.brandBlack,
                        shape: BoxShape.circle,
                      ),
                    ),
                    // Hour hand pointing to 2 o'clock
                    Transform.rotate(
                      angle: 1.0,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 1.8,
                          height: 6,
                          margin: const EdgeInsets.only(top: 3),
                          color: AppColors.brandBlack,
                        ),
                      ),
                    ),
                    // Minute hand pointing to 12 o'clock
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 1.5,
                        height: 7,
                        margin: const EdgeInsets.only(top: 2),
                        color: AppColors.brandBlack,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Pulsing user location puck matching the brand identity
  Widget _buildGoogleLocationPuck() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Soft Animated Outer Crimson Pulse Aura
            Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.brandRed.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Obsidian Black Disk with White Border
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.brandBlack,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40181818),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                // Crisp White Inner Ring
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    // Solid Brand Red Center Dot
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.brandRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: Icon(
                icon,
                color: iconColor ?? AppColors.textPrimary,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isTop,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            borderRadius: BorderRadius.vertical(
              top: isTop ? const Radius.circular(28) : Radius.zero,
              bottom: !isTop ? const Radius.circular(28) : Radius.zero,
            ),
            onTap: onTap,
            child: Center(
              child: Icon(
                icon,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
