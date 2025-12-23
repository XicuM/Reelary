import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let apiKey = getEnvVar("GOOGLE_MAPS_API_KEY") {
      GMSServices.provideAPIKey(apiKey)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func getEnvVar(_ key: String) -> String? {
    // Try to find .env in flutter_assets
    if let path = Bundle.main.path(forResource: ".env", ofType: nil, inDirectory: "flutter_assets"),
       let content = try? String(contentsOfFile: path) {
      let lines = content.components(separatedBy: .newlines)
      for line in lines {
        let parts = line.components(separatedBy: "=")
        if parts.count >= 2 && parts[0].trimmingCharacters(in: .whitespaces) == key {
          return parts[1].trimmingCharacters(in: .whitespaces)
        }
      }
    }
    return nil
  }
}
