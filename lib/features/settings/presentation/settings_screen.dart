import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../destination/data/destination_history_repo.dart';

/// User settings for alert preferences, units, vibration modes, and privacy.
class SettingsScreen extends StatefulWidget {
  final DestinationHistoryRepository historyRepo;

  const SettingsScreen({super.key, required this.historyRepo});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _useMiles = false;
  bool _speedAwareAlerts = true;
  bool _overshootAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'ALERT BEHAVIOR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          _buildSwitchTile(
            title: 'Speed-Aware Dynamic Buffer',
            subtitle:
                'Triggers earlier on high-speed rail/express buses so you have time to wake up and gather bags.',
            value: _speedAwareAlerts,
            onChanged: (v) => setState(() => _speedAwareAlerts = v),
            icon: Icons.speed_rounded,
          ),
          const SizedBox(height: 12),

          _buildSwitchTile(
            title: 'Missed Stop / Overshoot Alarm',
            subtitle:
                'Sounds a distinct alert if distance starts increasing past your destination.',
            value: _overshootAlerts,
            onChanged: (v) => setState(() => _overshootAlerts = v),
            icon: Icons.alt_route_rounded,
          ),
          const SizedBox(height: 24),

          const Text(
            'MEASUREMENTS & UNITS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          _buildSwitchTile(
            title: 'Use Imperial Units (Miles / Feet)',
            subtitle: _useMiles
                ? 'Displaying miles and feet'
                : 'Displaying kilometers and meters',
            value: _useMiles,
            onChanged: (v) => setState(() => _useMiles = v),
            icon: Icons.straighten_rounded,
          ),
          const SizedBox(height: 24),

          const Text(
            'PRIVACY & LOCAL DATA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.alarmRed,
                  size: 20,
                ),
              ),
              title: const Text(
                'Clear All Search & Trip History',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Erase locally cached destinations from this phone',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              onTap: () async {
                await widget.historyRepo.clearHistory();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Local trip history cleared')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
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
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
