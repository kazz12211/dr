//
//  PlaylistViewController.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/08.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//  MIT License
//

import UIKit
import AVFoundation
import Photos

class PlaylistViewController: UIViewController {

    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    var videoFiles: [URL] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        showVideos()
    }

    

    @IBAction func dismiss(_ sender: Any) {
        dismiss(animated: true) {
            
        }
    }

    private func showVideos() {
        listVideoFiles()
        tableView.reloadData()
    }
    
    private func listVideoFiles() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        videoFiles = []
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions.skipsSubdirectoryDescendants)
            for fileURL in fileURLs {
                if fileURL.lastPathComponent.hasSuffix(".mp4") {
                    videoFiles.append(fileURL)
                }
            }
        } catch {
            print("error whilte enumerating files \(documentsURL.path): \(error.localizedDescription)")
        }
    }
}

extension PlaylistViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
        
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let viewController = storyboard?.instantiateViewController(withIdentifier: "player") as! PlayerViewController
        let url = videoFiles[indexPath.row]
        let asset = AVAsset(url:url)
        if asset.duration.seconds > 0 {
            viewController.setURL(url)
            let nav = UINavigationController(rootViewController: viewController)
            present(nav, animated: true, completion: nil)
        }
    }
}

extension PlaylistViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return videoFiles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VideoCell", for: indexPath) as! PlaylistCell
        let url = videoFiles[indexPath.row]
        cell.setURL(url)
        return cell
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return UITableViewCellEditingStyle.none
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let removeAction = UIContextualAction(style: .normal, title: "削除") { (action, view, success) in
            let url = self.videoFiles[indexPath.row]
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Error removing ", url)
            }
            self.videoFiles.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            success(true)
        }
        removeAction.image = UIImage(named: "icon_trash")
        removeAction.backgroundColor = .red
        return UISwipeActionsConfiguration(actions: [removeAction])
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let moveVideoAction = UIContextualAction(style: .normal, title: "Move", handler: {(action: UIContextualAction, view: UIView, success : (Bool) -> Void) in
            self.moveVideoToPhotoAlbum(at: indexPath)
            success(false)
        })
        moveVideoAction.image = UIImage(named: "icon_folder_download")
        moveVideoAction.backgroundColor = UIColor.blue
        return UISwipeActionsConfiguration(actions: [moveVideoAction])
    }
    
    func moveVideoToPhotoAlbum(at indexPath: IndexPath) {
        let fileURL = videoFiles[indexPath.row]
        if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileURL.path) {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            }) { (saved, error) in
                if saved {
                    do {
                        try FileManager.default.removeItem(at: fileURL)
                        self.videoFiles.remove(at: indexPath.row)
                        DispatchQueue.main.async {
                            self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        }
                    } catch {
                        print("could not remove video file at path \(fileURL.path)")
                    }
                }
            }
        }
    }

}

