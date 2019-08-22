/*
 See the LICENSE file at the root of this repository for sample licensing information.
 */

import ARKit
import os
import UIKit

struct ProjectInfo {
  let projectName: String
  let torchkitProj: String
  let projectDesc: String
}

/**
 This is a simple example of a product catalog type application.  In this case, we are displaying example projects from
 Torch.
 */
class ProjectGalleryViewController: UICollectionViewController {
  /// Called by ProjectGalleryCell when a project has been selected.
  fileprivate func projectSelected(project: ProjectInfo) {
    let vc = TorchProjectViewController(projectURL: Bundle.main.url(forResource: project.torchkitProj, withExtension: "torchkitproj")!)
    vc.navigationItem.title = project.projectName
    navigationController?.pushViewController(vc, animated: true)
  }

  /// The project list.  Often this would be serialized from a database or file on disk.
  private let projects = [
    ProjectInfo(projectName: "One Asset", torchkitProj: "bigasset", projectDesc: "This is an example of using one asset and Torch's animation system to create an interesting project."),
    ProjectInfo(projectName: "Responsive AR", torchkitProj: "responsive-ar", projectDesc: "This is a template available in the Torch app showcasing content that is responsive to where the user has placed it."),
    ProjectInfo(projectName: "Desk Buddy", torchkitProj: "deskbuddy", projectDesc: "Desk Buddy shows off runtime object manipulation by displaying a cute animal to place on your desk.")
  ]

  private let reuseIdentifier = "ProjectCell"

  private func project(for indexPath: IndexPath) -> ProjectInfo {
    return self.projects[indexPath.item]
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.navigationItem.title = "Project Gallery"
    self.adjustLayout()
  }

  // MARK: - UICollectionDataSource

  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return self.projects.count
  }

  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: self.reuseIdentifier, for: indexPath) as! ProjectGalleryCell
    cell.galleryVC = self
    cell.project = self.project(for: indexPath)

    return cell
  }

  override func viewWillLayoutSubviews() {
    self.adjustLayout()
  }

  private let minItemSpacing: CGFloat = 16
  private let itemWidth: CGFloat = 374
  private let itemHeight: CGFloat = 236
  private let headerHeight: CGFloat = 32
  private var lastWidth: CGFloat = 0.0
  private var layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()

  func adjustLayout() {
    if self.lastWidth != self.collectionView.bounds.width {
      self.lastWidth = self.collectionView.bounds.width
      // Create our custom flow layout that evenly space out the items, and have them in the center
      self.layout.itemSize = CGSize(width: self.itemWidth, height: self.itemHeight)
      self.layout.minimumInteritemSpacing = self.minItemSpacing
      self.layout.minimumLineSpacing = self.minItemSpacing
      self.layout.headerReferenceSize = CGSize(width: 0, height: self.headerHeight)

      // Find n, where n is the number of item that can fit into the collection view
      var n: CGFloat = 1
      let containerWidth = self.collectionView.bounds.width
      while true {
        let nextN = n + 1
        let totalWidth = (nextN * self.itemWidth) + (nextN - 1) * self.minItemSpacing
        if totalWidth > containerWidth {
          break
        } else {
          n = nextN
        }
      }

      // Calculate the section inset for left and right.
      // Setting this section inset will manipulate the items such that they will all be aligned horizontally center.
      let inset = max(minItemSpacing, floor((containerWidth - (n * self.itemWidth) - (n - 1) * self.minItemSpacing) / 2))
      self.layout.sectionInset = UIEdgeInsets(top: self.minItemSpacing, left: inset, bottom: self.minItemSpacing, right: inset)

      if self.collectionView.collectionViewLayout != self.layout {
        self.collectionView.collectionViewLayout = self.layout
      }
      self.layout.invalidateLayout()
    }
  }
}

class ProjectGalleryCell: UICollectionViewCell {
  @IBOutlet var projectNameLabel: UILabel!
  @IBOutlet var viewButton: UIButton!
  @IBOutlet var projectDescriptionLabel: UILabel!

  public var galleryVC: ProjectGalleryViewController?
  public var project: ProjectInfo? {
    didSet {
      self.layer.cornerRadius = 16
      self.layer.masksToBounds = true
      self.viewButton.layer.cornerRadius = self.viewButton.frame.size.height * 0.5
      self.viewButton.layer.masksToBounds = true

      self.projectNameLabel.text = self.project?.projectName
      self.viewButton.isEnabled = ARWorldTrackingConfiguration.isSupported
      self.projectDescriptionLabel?.text = self.project?.projectDesc
    }
  }

  @IBAction func viewProjectHit(_ sender: Any) {
    self.galleryVC?.projectSelected(project: self.project!)
  }
}
