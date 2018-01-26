//
//  PickerCell.swift
//  OpalImagePicker
//
//  Created by Gianluca Pisati on 25/01/18.
//  Copyright © 2018 Opal Orange LLC. All rights reserved.
//

import UIKit
import Photos

class PickerCell: UICollectionViewCell {
    
    static let scale: CGFloat = 3
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var overlayImageView: UIImageView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var numberLabel: UILabel!
    
    var photoAsset: PHAsset? {
        didSet {
            loadPhotoAssetIfNeeded()
        }
    }
    
    var number: Int?
    
    var size: CGSize? {
        didSet {
            loadPhotoAssetIfNeeded()
        }
    }
    
    var url: URL? {
        didSet {
            loadURLIfNeeded()
        }
    }
    
    var indexPath: IndexPath?
    
    
    fileprivate var imageRequestID: PHImageRequestID?
    fileprivate var urlDataTask: URLSessionTask?
    var cache: NSCache<NSIndexPath, NSData>?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView?.image = nil
    }
    
    func setup(index: Int?){
        if(index != nil){
            numberLabel.text = "\(index!+1)"
            overlayImageView.image = UIImage(named:"circle-full")
        }else{
            numberLabel.text = ""
            overlayImageView.image = UIImage(named:"circle-empty")
        }
    }
    
    fileprivate func loadURLIfNeeded() {
        guard let url = self.url,
            let indexPath = self.indexPath else {
                activityIndicator?.stopAnimating()
                imageView?.image = nil
                return
        }
        
        //Check cache first to avoid downloading image.
        if let imageData = cache?.object(forKey: indexPath as NSIndexPath) as Data?,
            let image = UIImage(data: imageData) {
            activityIndicator?.stopAnimating()
            imageView?.image = image
            return
        }
        
        activityIndicator?.startAnimating()
        urlDataTask = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            guard indexPath == self?.indexPath else { return }
            
            DispatchQueue.main.async { // Correct
                self?.activityIndicator?.stopAnimating()
            }
            
            guard let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                //let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                let data = data, error == nil,
                let image = UIImage(data: data) else {
                    //broken link image
                    return
            }
            
            self?.cache?.setObject(data as NSData,
                                   forKey: indexPath as NSIndexPath,
                                   cost: data.count)
            
            DispatchQueue.main.async { [weak self] in
                self?.imageView?.image = image
            }
        }
        urlDataTask?.resume()
    }
    
    fileprivate func loadPhotoAssetIfNeeded() {
        guard let asset = photoAsset, let size = self.size, let indexPath = self.indexPath else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        
        let manager = PHImageManager.default()
        let newSize = CGSize(width: size.width * type(of: self).scale,
                             height: size.height * type(of: self).scale)
        
        
        //Check cache first to avoid downloading image.
        if let imageData = cache?.object(forKey: indexPath as NSIndexPath) as Data?,
            let image = UIImage(data: imageData) {
            activityIndicator?.stopAnimating()
            imageView?.image = image
            return
        }
        
        activityIndicator?.startAnimating()
        imageRequestID = manager.requestImage(for: asset, targetSize: newSize, contentMode: .aspectFill, options: options, resultHandler: { [weak self] (result, info) in
            self?.activityIndicator?.stopAnimating()
            self?.imageRequestID = nil
            guard let result = result else {
                self?.imageView?.image = nil
                return
            }
            let data = UIImagePNGRepresentation(result)
            self?.cache?.setObject(data! as NSData,
                                   forKey: indexPath as NSIndexPath,
                                   cost: data!.count)
            
            self?.imageView?.image = result
        })
    }
}
