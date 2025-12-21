import Flutter
import UserNotifications
import EntrigSDK

public class EntrigPlugin: NSObject, FlutterPlugin {

    // MARK: - Properties
    static var channel: FlutterMethodChannel?

    // MARK: - Plugin Registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.entrig.plugin.notifications", binaryMessenger: registrar.messenger())
        EntrigPlugin.channel = channel
        let instance = EntrigPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Set up SDK listeners
        Entrig.setOnForegroundNotificationListener(instance)
        Entrig.setOnNotificationOpenedListener(instance)
    }

    // MARK: - Public API for Manual Integration

    /// Call this from application:didRegisterForRemoteNotificationsWithDeviceToken:
    public static func didRegisterForRemoteNotifications(deviceToken: Data) {
        Entrig.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    /// Call this from application:didFailToRegisterForRemoteNotificationsWithError:
    public static func didFailToRegisterForRemoteNotifications(error: Error) {
        Entrig.didFailToRegisterForRemoteNotifications(error: error)
    }

    /// Call this from application:didFinishLaunchingWithOptions: to handle cold start notifications
    public static func checkLaunchNotification(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        Entrig.checkLaunchNotification(launchOptions)
    }

    /// Call this from userNotificationCenter:willPresentNotification:withCompletionHandler:
    public static func willPresentNotification(_ notification: UNNotification) {
        Entrig.willPresentNotification(notification)
    }

    /// Call this from userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:
    public static func didReceiveNotification(_ response: UNNotificationResponse) {
        Entrig.didReceiveNotification(response)
    }

    // MARK: - Method Call Handler
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "init":
            handleInit(call: call, result: result)

        case "register":
            handleRegister(call: call, result: result)

        case "requestPermission":
            handleRequestPermission(result: result)

        case "unregister":
            handleUnregister(result: result)

        case "getInitialNotification":
            handleGetInitialNotification(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Method Handlers
    private func handleInit(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let key = args["apiKey"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                                message: "apiKey is required",
                                details: nil))
            return
        }

        guard !key.isEmpty else {
            result(FlutterError(code: "INVALID_API_KEY",
                                message: "API key cannot be empty",
                                details: nil))
            return
        }

        let handlePermission = args["handlePermission"] as? Bool ?? true
        let config = EntrigConfig(apiKey: key, handlePermission: handlePermission)

        Entrig.configure(config: config) { success, error in
            DispatchQueue.main.async {
                if success {
                    result(nil)
                } else {
                    result(FlutterError(code: "INIT_ERROR",
                                        message: error ?? "Failed to initialize SDK",
                                        details: nil))
                }
            }
        }
    }

    private func handleRegister(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let userId = args["userId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                                message: "userId is required",
                                details: nil))
            return
        }

        Entrig.register(userId: userId, sdk: "flutter") { success, error in
            DispatchQueue.main.async {
                if success {
                    result(nil)
                } else {
                    result(FlutterError(code: "REGISTER_ERROR",
                                        message: error ?? "Registration failed",
                                        details: nil))
                }
            }
        }
    }

    private func handleRequestPermission(result: @escaping FlutterResult) {
        Entrig.requestPermission { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "PERMISSION_ERROR",
                                        message: error.localizedDescription,
                                        details: nil))
                    return
                }
                result(granted)
            }
        }
    }

    private func handleUnregister(result: @escaping FlutterResult) {
        Entrig.unregister { success, error in
            DispatchQueue.main.async {
                if success {
                    result(nil)
                } else {
                    result(FlutterError(code: "UNREGISTER_ERROR",
                                        message: error ?? "Unregistration failed",
                                        details: nil))
                }
            }
        }
    }

    private func handleGetInitialNotification(result: @escaping FlutterResult) {
        if let event = Entrig.getInitialNotification() {
            let payload: [String: Any] = [
                "title": event.title ?? "",
                "body": event.body ?? "",
                "data": event.data ?? [:],
                "isForeground": false
            ]
            result(payload)
        } else {
            result(nil)
        }
    }
}

// MARK: - SDK Listeners
extension EntrigPlugin: OnNotificationReceivedListener {
    public func onNotificationReceived(_ event: NotificationEvent) {
        sendNotificationToFlutter(event: event, isForeground: true)
    }
}

extension EntrigPlugin: OnNotificationClickListener {
    public func onNotificationClick(_ event: NotificationEvent) {
        sendNotificationToFlutter(event: event, isForeground: false)
    }
}

// MARK: - Helper Methods
extension EntrigPlugin {
    private func sendNotificationToFlutter(event: NotificationEvent, isForeground: Bool) {
        let payload: [String: Any] = [
            "title": event.title ?? "",
            "body": event.body ?? "",
            "data": event.data ?? [:],
            "isForeground": isForeground
        ]

        EntrigPlugin.channel?.invokeMethod("onNotificationReceived", arguments: payload)
    }
}
