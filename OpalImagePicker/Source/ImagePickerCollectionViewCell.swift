//
//  ImagePickerCollectionViewCell.swift
//  OpalImagePicker
//
//  Created by Kris Katsanevas on 1/15/17.
//  Copyright © 2017 Opal Orange LLC. All rights reserved.
//

import UIKit
import Photos

class ImagePickerCollectionViewCell: UICollectionViewCell {
    
    static let scale: CGFloat = 3
    static let reuseId = String(describing: ImagePickerCollectionViewCell.self)
    
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
    
    var indexPath: IndexPath? {
        didSet {
            loadURLIfNeeded()
        }
    }
    
    var cache: NSCache<NSIndexPath, NSData>?
    
    var selectionTintColor: UIColor = UIColor.black.withAlphaComponent(0.8) {
        didSet {
            overlayView?.backgroundColor = selectionTintColor
        }
    }
    
    open var selectionImageTintColor: UIColor = .white {
        didSet {
            overlayImageView?.tintColor = selectionImageTintColor
        }
    }
    
  
    weak var imageView: UIImageView?
    weak var activityIndicator: UIActivityIndicatorView?
    
    weak var overlayView: UIView?
    weak var overlayImageView: UIImageView?
    weak var numberLabel: UILabel?
    
    fileprivate var imageRequestID: PHImageRequestID?
    fileprivate var urlDataTask: URLSessionTask?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .lightGray
        
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        contentView.addSubview(activityIndicator)
        self.activityIndicator = activityIndicator
        
        let imageView = UIImageView(frame: frame)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        self.imageView = imageView
        
        let overlayImageView = UIImageView(frame: CGRect.init(x: frame.origin.x, y: frame.origin.y, width: 30, height: 30))
        overlayImageView.translatesAutoresizingMaskIntoConstraints = false
        overlayImageView.image = UIImage(named: "circle-empty")
        contentView.addSubview(overlayImageView)
        self.overlayImageView = overlayImageView
        
        let numberLabel = UILabel(frame: CGRect.init(x: frame.origin.x, y: frame.origin.y, width: 30, height: 30))
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        numberLabel.textColor = .white
        numberLabel.textAlignment = .center
        contentView.addSubview(numberLabel)
        self.numberLabel = numberLabel
        
        NSLayoutConstraint.activate([
            contentView.leftAnchor.constraint(equalTo: imageView.leftAnchor),
            contentView.rightAnchor.constraint(equalTo: imageView.rightAnchor),
            contentView.topAnchor.constraint(equalTo: imageView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            contentView.centerXAnchor.constraint(equalTo: activityIndicator.centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: activityIndicator.centerYAnchor),
            
            overlayImageView.widthAnchor.constraint(equalToConstant: 30),
            overlayImageView.heightAnchor.constraint(equalToConstant: 30),
            contentView.rightAnchor.constraint(equalTo: overlayImageView.rightAnchor),
            contentView.bottomAnchor.constraint(equalTo: overlayImageView.bottomAnchor),
            
            numberLabel.widthAnchor.constraint(equalToConstant: 30),
            numberLabel.heightAnchor.constraint(equalToConstant: 30),
            contentView.rightAnchor.constraint(equalTo: numberLabel.rightAnchor),
            contentView.bottomAnchor.constraint(equalTo: numberLabel.bottomAnchor)
            ])
        layoutIfNeeded()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView?.image = nil
        
        //Cancel requests if needed
        urlDataTask?.cancel()
        let manager = PHImageManager.default()
        guard let imageRequestID = self.imageRequestID else { return }
        manager.cancelImageRequest(imageRequestID)
        self.imageRequestID = nil
    }
    
    fileprivate func loadPhotoAssetIfNeeded() {
        guard let asset = photoAsset, let size = self.size else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        
        let manager = PHImageManager.default()
        let newSize = CGSize(width: size.width * type(of: self).scale,
                             height: size.height * type(of: self).scale)
        activityIndicator?.startAnimating()
        imageRequestID = manager.requestImage(for: asset, targetSize: newSize, contentMode: .aspectFill, options: options, resultHandler: { [weak self] (result, info) in
            self?.activityIndicator?.stopAnimating()
            self?.imageRequestID = nil
            guard let result = result else {
                self?.imageView?.image = nil
                return
            }
            self?.imageView?.image = result
        })
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
    
    fileprivate func addOverlay(_ animated: Bool) {
        guard self.overlayImageView != nil else { return }
        
        self.overlayImageView?.removeFromSuperview()

        let overlayImageView = UIImageView(frame: CGRect.init(x: frame.origin.x, y: frame.origin.y, width: 30, height: 30))
        overlayImageView.translatesAutoresizingMaskIntoConstraints = false
        overlayImageView.image = UIImage(named: "circle-full")
        contentView.addSubview(overlayImageView)
        self.overlayImageView = overlayImageView
        
        let numberLabel = UILabel(frame: CGRect.init(x: frame.origin.x, y: frame.origin.y, width: 30, height: 30))
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        numberLabel.textColor = .white
        numberLabel.textAlignment = .center
        if number != nil{
            numberLabel.text = "\(number!)"
        }else{
            numberLabel.text = ""
        }
        
        contentView.addSubview(numberLabel)
        self.numberLabel = numberLabel
        
        NSLayoutConstraint.activate([
            overlayImageView.widthAnchor.constraint(equalToConstant: 30),
            overlayImageView.heightAnchor.constraint(equalToConstant: 30),
            contentView.rightAnchor.constraint(equalTo: overlayImageView.rightAnchor),
            contentView.bottomAnchor.constraint(equalTo: overlayImageView.bottomAnchor),
            numberLabel.widthAnchor.constraint(equalToConstant: 30),
            numberLabel.heightAnchor.constraint(equalToConstant: 30),
            contentView.rightAnchor.constraint(equalTo: numberLabel.rightAnchor),
            contentView.bottomAnchor.constraint(equalTo: numberLabel.bottomAnchor)
            ])
        layoutIfNeeded()
        
        let duration = animated ? 0.2 : 0.0
        UIView.animate(withDuration: duration, animations: {
            overlayImageView.alpha = 1
        })
    }
    
    fileprivate func removeOverlay(_ animated: Bool) {
        if(self.overlayImageView != nil && self.numberLabel != nil){
                self.overlayImageView?.removeFromSuperview()
                self.numberLabel?.removeFromSuperview()
                return
        }
        
        let overlayImageView = UIImageView(frame: CGRect.init(x: frame.origin.x, y: frame.origin.y, width: 30, height: 30))
        overlayImageView.translatesAutoresizingMaskIntoConstraints = false
        overlayImageView.image = UIImage(named: "circle-empty")
        contentView.addSubview(overlayImageView)
        self.overlayImageView = overlayImageView
        
        NSLayoutConstraint.activate([
            overlayImageView.widthAnchor.constraint(equalToConstant: 30),
            overlayImageView.heightAnchor.constraint(equalToConstant: 30),
            contentView.rightAnchor.constraint(equalTo: overlayImageView.rightAnchor),
            contentView.bottomAnchor.constraint(equalTo: overlayImageView.bottomAnchor)
            ])
        layoutIfNeeded()
    }
    
    func setup(number: Int?){
        if(number != nil){
            self.addOverlay(true)
        }else{
            self.removeOverlay(true)
        }
    }
    
}
