/*
 See the LICENSE file at the root of this repository for sample licensing information.
 */

import ARKit

class Plane: SCNNode {
  let meshNode: SCNNode
  var classificationNode: SCNNode?
  let planeColor: UIColor

  /// - Tag: VisualizePlane
  init(anchor: ARPlaneAnchor, in sceneView: ARSCNView, withColor color: UIColor) {
    // Create a mesh to visualize the estimated shape of the plane.
    guard let meshGeometry = ARSCNPlaneGeometry(device: sceneView.device!)
    else { fatalError("Can't create plane geometry") }
    self.planeColor = color
    meshGeometry.update(from: anchor.geometry)
    self.meshNode = SCNNode(geometry: meshGeometry)

    super.init()

    self.setupMeshVisualStyle()

    // Add the plane geometry as child nodes so they appear in the scene.
    addChildNode(self.meshNode)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupMeshVisualStyle() {
    // Make the plane visualization semitransparent to clearly show real-world placement.
    self.meshNode.opacity = 0.25

    // Use color and blend mode to make planes stand out.
    guard let material = meshNode.geometry?.firstMaterial
    else { fatalError("ARSCNPlaneGeometry always has one material") }
    material.diffuse.contents = self.planeColor
  }
}
