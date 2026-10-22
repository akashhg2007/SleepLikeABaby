import Foundation
import CoreLocation
import UserNotifications
import AVFoundation

/// Production CoreLocation manager configured for continuous background updates,
/// lock-screen distance evaluation, and local notifications.
class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let clManager = CLLocationManager()
    private var destCoordinate: CLLocationCoordinate2D?
    private var destName: String = "Destination"
    private var alertRadius: Double = 1000.0

    private var isAlarmTriggered = false
    private var isSnoozed = false
    private var snoozeEndTime: Date?

    var locationUpdateHandler: (([String: Any]) -> Void)?
    var alarmEventHandler: ((String) -> Void)?

    private override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        clManager.distanceFilter = 5.0 // Update every 5 meters
        clManager.activityType = .otherNavigation

        // Enable background updates
        clManager.allowsBackgroundLocationUpdates = true
        clManager.pausesLocationUpdatesAutomatically = false
        if #available(iOS 11.0, *) {
            clManager.showsBackgroundLocationIndicator = true
        }
    }

    func requestPermissions() {
        clManager.requestAlwaysAuthorization()
    }

    func startTracking(destLat: Double, destLng: Double, name: String, radius: Double) {
        destCoordinate = CLLocationCoordinate2D(latitude: destLat, longitude: destLng)
        destName = name
        alertRadius = radius
        isAlarmTriggered = false
        isSnoozed = false

        AudioSessionManager.shared.configurePlaybackSession()
        clManager.startUpdatingLocation()
    }

    func stopTracking() {
        clManager.stopUpdatingLocation()
        destCoordinate = nil
        isAlarmTriggered = false
        AudioSessionManager.shared.deactivateSession()
    }

    func snoozeAlarm(durationMinutes: Int = 3) {
        isSnoozed = true
        snoozeEndTime = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))
        alarmEventHandler?("snooze")
    }

    func dismissAlarm() {
        isAlarmTriggered = false
        stopTracking()
        alarmEventHandler?("dismiss")
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        var distanceMeters: Double = 0.0
        if let destCoord = destCoordinate {
            let destLocation = CLLocation(latitude: destCoord.latitude, longitude: destCoord.longitude)
            distanceMeters = location.distance(from: destLocation)
        }

        // Payload for Flutter EventChannel
        let payload: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "speed": max(0.0, location.speed),
            "bearing": max(0.0, location.course),
            "altitude": location.altitude,
            "timestamp": Int64(location.timestamp.timeIntervalSince1970 * 1000),
            "distanceMeters": distanceMeters
        ]
        locationUpdateHandler?(payload)

        // Check snooze expiry
        if isSnoozed, let end = snoozeEndTime, Date() >= end {
            isSnoozed = false
        }

        // Native Alarm Trigger Fallback
        if !isAlarmTriggered && !isSnoozed && destCoordinate != nil && distanceMeters <= alertRadius {
            triggerNativeAlert(distanceMeters: distanceMeters)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("CoreLocation failed: \(error.localizedDescription)")
    }

    private func triggerNativeAlert(distanceMeters: Double) {
        isAlarmTriggered = true
        alarmEventHandler?("alarm_triggered")

        // Schedule urgent time-sensitive local notification
        let content = UNMutableNotificationContent()
        content.title = "WAKE UP! Approaching \(destName)"
        content.body = "You are within \(Int(alertRadius))m of your stop! Prepare to exit."
        content.sound = UNNotificationSound.defaultCritical
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let request = UNNotificationRequest(
            identifier: "alarm_arrival_notification",
            content: content,
            trigger: nil // immediate
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
}
