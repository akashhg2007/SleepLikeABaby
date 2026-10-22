import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../data/destination_history_repo.dart';
import '../data/nominatim_search_api.dart';
import '../domain/destination.dart';

/// Modal bottom sheet providing debounced place search, recent destinations,
/// and map picker navigation.
class DestinationSearchSheet extends StatefulWidget {
  final NominatimSearchApi searchApi;
  final DestinationHistoryRepository historyRepo;
  final LatLng? userLocation;
  final VoidCallback onOpenMapPicker;

  const DestinationSearchSheet({
    super.key,
    required this.searchApi,
    required this.historyRepo,
    this.userLocation,
    required this.onOpenMapPicker,
  });

  @override
  State<DestinationSearchSheet> createState() => _DestinationSearchSheetState();
}

class _DestinationSearchSheetState extends State<DestinationSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<Destination> _searchResults = [];
  List<Destination> _recents = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  void _loadRecents() {
    setState(() {
      _recents = widget.historyRepo.getRecentDestinations();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _searchResults = [];
        _errorMessage = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final results = await widget.searchApi.search(
          query,
          proximityLat: widget.userLocation?.latitude,
          proximityLng: widget.userLocation?.longitude,
        );

        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _isLoading = false;
          if (results.isEmpty) {
            _errorMessage = 'No destinations found for "$query"';
          }
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to search. Check internet connection.';
        });
      }
    });
  }

  void _selectDestination(Destination destination) {
    widget.historyRepo.addRecent(destination);
    Navigator.of(context).pop(destination);
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Pull Bar
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'Choose Destination',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Search Input Box
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  autofocus: true,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search station, stop, landmark...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                    ),
                    suffixIcon: hasQuery
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                  ),
                ),
              ),

              // Action Shortcuts (Map Picker & Location)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.map_rounded,
                          color: AppColors.secondary,
                          size: 18,
                        ),
                        label: const Text(
                          'Pick on Map',
                          style: TextStyle(fontSize: 14),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onOpenMapPicker();
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Search Results or Recents List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : hasQuery
                    ? _buildSearchResults(scrollController)
                    : _buildRecentsList(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(ScrollController scrollController) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      itemCount: _searchResults.length,
      separatorBuilder: (_, _) => const Divider(indent: 64),
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          title: Text(
            item.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            item.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          onTap: () => _selectDestination(item),
        );
      },
    );
  }

  Widget _buildRecentsList(ScrollController scrollController) {
    if (_recents.isEmpty) {
      return const Center(
        child: Text(
          'No recent destinations yet',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView(
      controller: scrollController,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RECENT & SAVED',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              TextButton(
                onPressed: () async {
                  await widget.historyRepo.clearHistory();
                  _loadRecents();
                },
                child: const Text(
                  'Clear',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
        ..._recents.map((item) {
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.isFavorite ? Icons.star_rounded : Icons.history_rounded,
                color: item.isFavorite
                    ? AppColors.warningAmber
                    : AppColors.secondary,
                size: 20,
              ),
            ),
            title: Text(
              item.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              item.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            trailing: IconButton(
              icon: Icon(
                item.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: item.isFavorite
                    ? AppColors.warningAmber
                    : AppColors.textMuted,
              ),
              onPressed: () async {
                await widget.historyRepo.toggleFavorite(item.id);
                _loadRecents();
              },
            ),
            onTap: () => _selectDestination(item),
          );
        }),
      ],
    );
  }
}
