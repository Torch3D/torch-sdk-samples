/*
 See the LICENSE file at the root of this repository for sample licensing information.
 */

import ARKit
import Metal
import SceneKit
import TorchKit
import UIKit

/**
 `TorchProjectViewController` is meant to be a simple starting point for displaying Torch projects inside of an iOS application.
 It performs the following tasks:

 * Manages the ARSceneView
 * Sets up scene lighting
 * Orchestrates setting the initial project anchor
 * Loads and display a Torch project
 */
class TorchProjectViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
  @IBOutlet var sceneView: ARSCNView!
  @IBOutlet var sessionInfoLabel: UILabel?

  /// Local URL of the project to view.
  public var projectURL: URL?

  // A reference to the TorchProjectNode of the project that is displayed.
  var torchProject: TorchProjectNode?

  // Last tick
  var lastTime: TimeInterval = 0.0

  var projectAnchorManager: ProjectAnchorManager?

  var viewLock: NSLock = NSLock()
  var viewCenter: CGPoint = CGPoint(x: 0, y: 0)
  var lastSize: CGSize = CGSize(width: 0, height: 0)

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // Start the view's AR session with a configuration that uses the rear camera,
    // device position and orientation tracking, and plane detection.
    let configuration = ARWorldTrackingConfiguration()
    configuration.planeDetection = [.horizontal]
    self.sceneView.session.run(configuration)

    // Set a delegate to track the number of plane anchors for providing UI feedback.
    self.sceneView.session.delegate = self

    // Prevent the screen from being dimmed after a while as users will likely
    // have long periods of interaction without touching the screen or buttons.
    UIApplication.shared.isIdleTimerDisabled = true

    // Show debug UI to view performance metrics (e.g. frames per second).
    self.sceneView.showsStatistics = true

    guard let projectURL = self.projectURL else {
      return // nothing to display
    }

    // Load the Torch Project here!
    do {
      self.torchProject = try TorchProjectNode(withProjectURL: projectURL, andDevice: self.sceneView.device!, arSession: self.sceneView.session)
    } catch {
      fatalError(error.localizedDescription)
    }

    // Set the project anchor
    if self.projectAnchorManager == nil {
      self.projectAnchorManager = ProjectAnchorManager(withSceneView: self.sceneView) { [weak self] in
        guard let projectVC = self, let torchProj = projectVC.torchProject else { return }
        // Add the gesture recognizers needed for object selection and manipulation
        TorchGestureManager.shared.addGestureRecognizers(to: projectVC.sceneView)
        // Setup scene lighting
        projectVC.setupSceneLighting()
        // Add the TorchProjectNode to the SceneKit scene
        projectVC.sceneView.scene.rootNode.addChildNode(torchProj)
        // Remove our reference ot the world anchor manager
        projectVC.projectAnchorManager = nil
        // Update UI state.
        guard let frame = projectVC.sceneView.session.currentFrame else { return }
        projectVC.updateSessionInfoLabel(for: frame,
                                         trackingState: frame.camera.trackingState)

        // Set a delegate to tick the torch project. Do this here because ProjectAnchorManager
        // uses the delegate to get plane updates.
        projectVC.sceneView.delegate = self
      }
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    // Pause ARSession as early as possible.
    self.sceneView.session.pause()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    // This gets called alot, use lastSize to only lock when needed.
    if self.view.frame.size != self.lastSize {
      self.viewLock.lock()
      self.viewCenter = CGPoint(x: self.view.frame.size.width * 0.5, y: self.view.frame.size.height * 0.5)
      self.viewLock.unlock()
      self.lastSize = self.view.frame.size
    }
  }

  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    guard self.projectAnchorManager == nil,
      let camTransform = self.sceneView.session.currentFrame?.camera.transform else {
      return
    }
    // Figure out how much time has passed
    let dt = self.lastTime != 0 ? time - self.lastTime : 0
    self.lastTime = time

    // Find out what object we are looking at
    self.viewLock.lock()
    let viewCenter = self.viewCenter
    self.viewLock.unlock()
    let hits = self.sceneView.hitTest(viewCenter, options: nil)
    let gazedNode: SCNNode? = !hits.isEmpty ? hits.first!.node : nil

    // Finally, advance project state with the above information
    self.torchProject!.tick(delta: dt, cameraTransform: camTransform, currentGazedNode: gazedNode)
  }

  func setupSceneLighting() {
    // Load the default environment map that Torch uses
    let envmapURL = Bundle.main.url(forResource: "envmap", withExtension: "png")!
    let envmapData = try! Data(contentsOf: envmapURL)
    let envmap = UIImage(data: envmapData)

    sceneView.automaticallyUpdatesLighting = false
    self.sceneView.autoenablesDefaultLighting = false
    self.sceneView.scene.lightingEnvironment.contents = envmap
    self.sceneView.scene.lightingEnvironment.intensity = 1.0

    // Add a floor plane (for shadows)
    let worldPlaneGeometry = SCNFloor()
    let worldPlaneNode = SCNNode(geometry: worldPlaneGeometry)
    let worldPlaneMaterial = SCNMaterial()
    worldPlaneGeometry.reflectivity = 0
    worldPlaneMaterial.diffuse.contents = UIColor.white
    worldPlaneMaterial.lightingModel = .physicallyBased
    worldPlaneMaterial.writesToDepthBuffer = true
    worldPlaneMaterial.colorBufferWriteMask = []
    worldPlaneGeometry.materials = [worldPlaneMaterial]
    worldPlaneNode.castsShadow = false
    self.sceneView.scene.rootNode.addChildNode(worldPlaneNode)

    // Setup a directional light (for shadows)
    let light = SCNLight()
    light.type = .directional
    light.shadowMode = .deferred
    light.intensity = 1000.0
    light.color = UIColor(white: 1.0, alpha: 1.0)
    light.castsShadow = true
    light.shadowColor = UIColor.black.withAlphaComponent(0.5)
    light.shadowBias = 32
    light.shadowSampleCount = 4
    light.shadowRadius = 5.0
    light.shadowMapSize = CGSize(width: 4096, height: 4096)
    let directionalLightNode = SCNNode()
    directionalLightNode.eulerAngles = SCNVector3(x: GLKMathDegreesToRadians(-80.0), y: -GLKMathDegreesToRadians(-180.0), z: 0.0)
    directionalLightNode.light = light
    self.sceneView.scene.rootNode.addChildNode(directionalLightNode)
  }

  // MARK: - ARSessionDelegate

  func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
    guard let frame = session.currentFrame else { return }
    self.updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
  }

  func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
    guard let frame = session.currentFrame else { return }
    self.updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
  }

  func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    self.updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
  }

  // MARK: - ARSessionObserver

  func sessionWasInterrupted(_ session: ARSession) {
    // Inform the user that the session has been interrupted, for example, by presenting an overlay.
    self.sessionInfoLabel?.text = "Session was interrupted"
  }

  func sessionInterruptionEnded(_ session: ARSession) {
    // Reset tracking and/or remove existing anchors if consistent tracking is required.
    self.sessionInfoLabel?.text = "Session interruption ended"
    self.resetTracking()
  }

  func session(_ session: ARSession, didFailWithError error: Error) {
    self.sessionInfoLabel?.text = "Session failed: \(error.localizedDescription)"
    guard error is ARError else { return }

    let errorWithInfo = error as NSError
    let messages = [
      errorWithInfo.localizedDescription,
      errorWithInfo.localizedFailureReason,
      errorWithInfo.localizedRecoverySuggestion
    ]

    // Remove optional error messages.
    let errorMessage = messages.compactMap { $0 }.joined(separator: "\n")

    DispatchQueue.main.async {
      // Present an alert informing about the error that has occurred.
      let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
      let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
        alertController.dismiss(animated: true, completion: nil)
        self.resetTracking()
      }
      alertController.addAction(restartAction)
      self.present(alertController, animated: true, completion: nil)
    }
  }

  private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
    // Update the UI to provide feedback on the state of the AR experience.
    let message: String

    switch trackingState {
    case .normal where frame.anchors.isEmpty:
      // No planes detected; provide instructions for this app's AR interactions.
      message = "Move the device around to detect horizontal and vertical surfaces."

    case .notAvailable:
      message = "Tracking unavailable."

    case .limited(.excessiveMotion):
      message = "Tracking limited - Move the device more slowly."

    case .limited(.insufficientFeatures):
      message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."

    case .limited(.initializing):
      message = "Initializing AR session."

    default:
      // No feedback needed when tracking is normal and planes are visible.
      // (Nor when in unreachable limited-tracking states.)
      message = self.projectAnchorManager != nil ? "Tap a plane to set project anchor" : ""
    }
    self.sessionInfoLabel?.text = message
  }

  private func resetTracking() {
    let configuration = ARWorldTrackingConfiguration()
    configuration.planeDetection = [.horizontal, .vertical]
    self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
  }
}
