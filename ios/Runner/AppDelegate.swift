import UIKit
import Flutter
import Firebase
import AppTrackingTransparency

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
       FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 14, *) {
                ATTrackingManager.requestTrackingAuthorization(completionHandler: { status in
                    switch status {
                    case .authorized:
                        print("enable tracking")
                    case .denied:
                        print("disable tracking")
                    default:
                        print("disable tracking")
                    }
                })
            }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
