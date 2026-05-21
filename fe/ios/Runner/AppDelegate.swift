import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let deepLinkChannelName = "sapahse/deep_link"
  private var deepLinkChannel: FlutterMethodChannel?
  private var pendingInitialLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL {
      pendingInitialLink = url.absoluteString
    }

    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      deepLinkChannel = FlutterMethodChannel(
        name: deepLinkChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      deepLinkChannel?.setMethodCallHandler { [weak self] call, result in
        if call.method == "getInitialLink" {
          result(self?.pendingInitialLink)
          self?.pendingInitialLink = nil
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    guard url.scheme == "sapahse" else {
      return super.application(app, open: url, options: options)
    }

    let link = url.absoluteString
    if let channel = deepLinkChannel {
      channel.invokeMethod("onDeepLink", arguments: link)
    } else {
      pendingInitialLink = link
    }

    return true
  }
}
