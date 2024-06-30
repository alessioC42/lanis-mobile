import UIKit
import Flutter
import workmanager
import flutter_local_notifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
      
    WorkmanagerPlugin.registerTask(withIdentifier: "notificationservice")
    // Set the minimum background fetch interval.
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60*40))
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
