
# TorchKit Sample Application

This is a simple example of how to load and unload Torch projects inside of a Swift based iOS application.  It could be the basis of a product catalog application with AR preview, or a chapter based training application with different Torch projects mapping to different tasks.

## Features

* Loads and displays multiple Torch projects.
* Has simple project anchoring.
* It gracefully handles devices that do not support ARKit by not allowing them to view the project.

## Project overview

1. In `AppDelegate.swift` we initialize and shutdown the TorchSDK.
2. In `ProjectGalleryViewController.swift` we display the project list and launch a `TorchProjectViewer` view controller to display the selected project.
3. `TorchProjectViewer.swift` is meant to be a template for displaying/executing Torch projects.
4. `WorldAnchorManager.swift` is a simple strategy for setting a world anchor for the Torch project.

## Notes on building/running

1. Be sure to run `pod update` in the sample directory to download and install the TorchKit pod.
2. Request an API key from Torch.
3. Open `AppDelegate.swift` and replace the API key in this line: `TorchKit.shared.initSDK(apiKey: "INSERT API KEY HERE")`
4. Update the `Signing Settings` under `Build Settings` to use your Apple account.
5. Run the sample application on a device.
