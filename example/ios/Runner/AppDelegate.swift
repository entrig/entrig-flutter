import Flutter
import entrig
import UserNotifications
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Setup Entrig notification handling
    UNUserNotificationCenter.current().delegate = self
    EntrigPlugin.checkLaunchNotification(launchOptions)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication,
      didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    EntrigPlugin.didRegisterForRemoteNotifications(deviceToken: deviceToken)
  }

  override func application(_ application: UIApplication,
      didFailToRegisterForRemoteNotificationsWithError error: Error) {
    EntrigPlugin.didFailToRegisterForRemoteNotifications(error: error)
  }

  // MARK: - UNUserNotificationCenterDelegate
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    EntrigPlugin.willPresentNotification(notification)
    completionHandler(EntrigPlugin.foregroundPresentationOptions())
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
    EntrigPlugin.didReceiveNotification(response)
    completionHandler()
  }

}
