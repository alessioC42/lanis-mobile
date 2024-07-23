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
    
    if #available(iOS 13.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
    
    WorkmanagerPlugin.registerTask(withIdentifier: "notificationservice")
    
      WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "io.github.alessioc42.notificationservice", frequency: NSNumber(value: 30 * 60))
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(30 * 60))
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
