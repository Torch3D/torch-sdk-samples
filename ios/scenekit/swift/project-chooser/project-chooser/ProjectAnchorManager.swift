/*
 See the LICENSE file at the root of this repository for sample licensing information.
 */

import ARKit
import SceneKit
import UIKit

/**
 `ProjectAnchorManager` manages the ARSession and UI until the user has set an anchor for the
 project.
 */
class ProjectAnchorManager: NSObject, ARSCNViewDelegate {
  let planeColor = UIColor(displayP3Red: 0.0, green: 0.1843137255, blue: 1.0, alpha: 0.50)

  var planes = Set<Plane>()
  var tapRec: UITapGestureRecognizer?
  var anchorSet: () -> Void
  var sceneView: ARSCNView

  /**
   `init` the ProjectAnchorManager

   - Parameter sceneView: The current `ARSCNView` that will eventually display the TorchProject
   - Parameter andStatusLabel: The `UILabel` object used to display the current anchoring status
   - Parameter anchorSet: The callback called when anchoring is complete.
   */
  init(withSceneView sceneView: ARSCNView, anchorSet cb: @escaping () -> Void) {
    self.anchorSet = cb
    self.sceneView = sceneView
    super.init()
    sceneView.delegate = self
    self.tapRec = UITapGestureRecognizer(target: self, action: #selector(self.handleTap))
    sceneView.addGestureRecognizer(self.tapRec!)
  }

  @objc func handleTap(sender: UITapGestureRecognizer) {
    guard sender.state == .ended else { return }

    let location: CGPoint = sender.location(in: self.sceneView)
    let hits = self.sceneView.hitTest(location, options: nil)

    guard !hits.isEmpty else { return }

    for hit in hits {
      let tappedNode = hit.node

      guard
        let _ = tappedNode.parent as? Plane,
        let camera = sceneView.session.currentFrame?.camera else { continue }

      let coord = hit.worldCoordinates
      let coord4 = simd_float4(coord.x, coord.y, coord.z, 1)

      let (_, _, cameraForward, _) = camera.transform.columns
      let forward = simd_normalize(simd_float3(cameraForward.x, 0, cameraForward.z))
      let up = simd_float3(0, 1, 0)
      let right = simd_cross(up, forward)

      let transform = simd_float4x4(
        simd_make_float4(right),
        simd_make_float4(up),
        simd_make_float4(forward),
        coord4
      )

      self.sceneView.session.setWorldOrigin(relativeTransform: transform)
      self.sceneView.removeGestureRecognizer(self.tapRec!)
      self.sceneView.delegate = nil

      self.planes.forEach { $0.removeFromParentNode() }
      self.anchorSet()

      break
    }
  }

  // MARK: - ARSCNViewDelegate

  func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    // Place content only for anchors found by plane detection.
    guard let planeAnchor = anchor as? ARPlaneAnchor else { return }

    // Create a custom object to visualize the plane geometry
    let plane = Plane(anchor: planeAnchor, in: sceneView, withColor: self.planeColor)
    self.planes.insert(plane)

    // Add the visualization to the ARKit-managed node so that it tracks
    // changes in the plane anchor as plane estimation continues.
    node.addChildNode(plane)
  }

  func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    // Update only anchors and nodes set up by `renderer(_:didAdd:for:)`.
    guard let planeAnchor = anchor as? ARPlaneAnchor,
      let plane = node.childNodes.first as? Plane
    else { return }

    // Update ARSCNPlaneGeometry to the anchor's new estimated shape.
    if let planeGeometry = plane.meshNode.geometry as? ARSCNPlaneGeometry {
      planeGeometry.update(from: planeAnchor.geometry)
    }
  }
}
