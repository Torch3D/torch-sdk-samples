//
//  AppDelegate.swift
//  torchkit-sample
//
//  Created by Brian Richardson on 8/7/19.
//  Copyright © 2019 Torch 3D Inc. All rights reserved.
//

import os
import TorchKit
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  var alertWindow: UIWindow?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    //
    // This is a good spot to initialize the TorchSDK.  This is safe to do even if the user's phone does not support ARKit
    //
    do {
      try TorchKit.shared.initSDK(apiKey: "INSERT API KEY HERE")
    } catch TorchInitError.invalidApiKey {
      self.showAlert(title: "Invalid API Key", message: "Please request an API key at:\nhttps://home.torch.app/account/api")
    } catch {
      self.showAlert(title: "Unknown Error", message: "Unknown error initializing the Torch SDK. Please contact support@torch.app")
    }
    return true
  }

  func showAlert(title: String, message: String) {
    self.alertWindow = UIWindow(frame: UIScreen.main.bounds)
    self.alertWindow?.rootViewController = UIViewController()
    self.alertWindow?.windowLevel = UIWindow.Level.alert + 1
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    self.alertWindow?.makeKeyAndVisible()
    self.alertWindow?.rootViewController?.present(alert, animated: true, completion: nil)
  }

  func applicationWillTerminate(_ application: UIApplication) {
    //
    // This is a good spot to shutdown the TorchSDK.
    //
    TorchKit.shared.shutdownSDK()
  }
}
