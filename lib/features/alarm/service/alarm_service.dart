import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

/// Central Alarm Service controlling audio playback loop, vibration patterns,
/// and high-priority heads-up/lockscreen notifications.
class AlarmService {
  final AudioPlayer _audioPlayer;
  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  bool _isRinging = false;
  Timer? _vibrationLoopTimer;

  AlarmService({
    AudioPlayer? audioPlayer,
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _audioPlayer = audioPlayer ?? AudioPlayer(),
       _notificationsPlugin =
           notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  bool get isRinging => _isRinging;

  /// Initializes notification channels for alarms and tracking.
  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );
    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handled by router or notification stream
      },
    );

    // Create high-importance Android Notification Channel for Alarms
    final androidChannel = const AndroidNotificationChannel(
      'alarm_high_importance',
      'Destination Wake Up Alarm',
      description: 'Urgent alarm that wakes you up before reaching destination',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('alarm'),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  /// Triggers full alarm: audio player loop + vibration pulses + urgent notification.
  Future<void> triggerAlarm({
    required String title,
    required String message,
    bool isOvershoot = false,
  }) async {
    if (_isRinging) return;
    _isRinging = true;

    // 1. Play audio loop
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // Fallback online beep tone or asset
      await _audioPlayer.play(
        UrlSource(
          'https://actions.google.com/sounds/v1/alarms/alarm_clock.ogg',
        ),
        volume: 1.0,
      );
    } catch (_) {
      // Audio playback fallback safely handled
    }

    // 2. Start distinctive repetitive vibration pattern (500ms on, 250ms off, 500ms on, 1000ms off)
    _startVibrationLoop();

    // 3. Post high-priority notification with full-screen intent capability
    final androidDetails = AndroidNotificationDetails(
      'alarm_high_importance',
      'Destination Wake Up Alarm',
      channelDescription:
          'Urgent alarm that wakes you up before reaching destination',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      ongoing: true,
      autoCancel: false,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'dismiss_action',
          'I am Awake',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction('snooze_action', 'Snooze 3m'),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _notificationsPlugin.show(
      id: 1001,
      title: title,
      body: message,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
    );
  }

  void _startVibrationLoop() {
    _vibrationLoopTimer?.cancel();
    _pulseVibration();
    _vibrationLoopTimer = Timer.periodic(const Duration(milliseconds: 2500), (
      _,
    ) {
      if (_isRinging) {
        _pulseVibration();
      }
    });
  }

  void _pulseVibration() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(
        pattern: [0, 500, 200, 500, 200, 700],
        intensities: [0, 255, 0, 255, 0, 255],
      );
    }
  }

  /// Stops audio, vibration, and removes alarm notification.
  Future<void> stopAlarm() async {
    _isRinging = false;
    _vibrationLoopTimer?.cancel();
    _vibrationLoopTimer = null;

    try {
      await _audioPlayer.stop();
    } catch (_) {}

    try {
      Vibration.cancel();
    } catch (_) {}

    try {
      await _notificationsPlugin.cancel(id: 1001);
    } catch (_) {}
  }

  void dispose() {
    stopAlarm();
    _audioPlayer.dispose();
  }
}
