//
//  PickerCell.swift
//  OpalImagePicker
//
//  Created by Gianluca Pisati on 25/01/18.
//  Copyright © 2018 Opal Orange LLC. All rights reserved.
//

import UIKit

class PickerCell: UICollectionViewCell {
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var overlayImageView: UIImageView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var numberLabel: UILabel!
    
    var url: URL? {
        didSet {
            loadURLIfNeeded()
        }
    }
    
    var indexPath: IndexPath? {
        didSet {
            loadURLIfNeeded()
        }
    }
    
    func setup(index: Int?){
        if(index != nil){
            numberLabel.text = "\(index!+1)"
        }
        
        activityIndicator.startAnimating()
    }
    fileprivate var urlDataTask: URLSessionTask?
    var cache: NSCache<NSIndexPath, NSData>?
    
    
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
}
