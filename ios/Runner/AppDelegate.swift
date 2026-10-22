import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, FlutterStreamHandler {

    private let TRIP_METHOD_CHANNEL = "com.sleeplikeababy/trip_service"
    private let LOCATION_EVENT_CHANNEL = "com.sleeplikeababy/location_stream"
    private let ALARM_EVENT_CHANNEL = "com.sleeplikeababy/alarm_events"

    private var locationEventSink: FlutterEventSink?
    private var alarmEventSink: FlutterEventSink?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        setupPlatformChannels(messenger: engineBridge.binaryMessenger)
    }

    private func setupPlatformChannels(messenger: FlutterBinaryMessenger) {
        // MethodChannel
        let methodChannel = FlutterMethodChannel(name: TRIP_METHOD_CHANNEL, binaryMessenger: messenger)
        methodChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "startTracking":
                guard let args = call.arguments as? [String: Any],
                      let lat = args["destLat"] as? Double,
                      let lng = args["destLng"] as? Double else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing coordinates", details: nil))
                    return
                }
                let name = args["destName"] as? String ?? "Destination"
                let radius = args["alertRadius"] as? Double ?? 1000.0

                LocationManager.shared.startTracking(destLat: lat, destLng: lng, name: name, radius: radius)
                result(true)

            case "stopTracking":
                LocationManager.shared.stopTracking()
                result(true)

            case "checkPermissions":
                result([
                    "hasLocation": true,
                    "hasBackgroundLocation": true,
                    "hasNotifications": true
                ])

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Location EventChannel
        let locationChannel = FlutterEventChannel(name: LOCATION_EVENT_CHANNEL, binaryMessenger: messenger)
        locationChannel.setStreamHandler(LocationStreamHandler())

        // Alarm EventChannel
        let alarmChannel = FlutterEventChannel(name: ALARM_EVENT_CHANNEL, binaryMessenger: messenger)
        alarmChannel.setStreamHandler(AlarmStreamHandler())
    }

    // Show banners even when app is foreground
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}

class LocationStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        LocationManager.shared.locationUpdateHandler = { payload in
            events(payload)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        LocationManager.shared.locationUpdateHandler = nil
        return nil
    }
}

class AlarmStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        LocationManager.shared.alarmEventHandler = { eventName in
            events(eventName)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        LocationManager.shared.alarmEventHandler = nil
        return nil
    }
}
