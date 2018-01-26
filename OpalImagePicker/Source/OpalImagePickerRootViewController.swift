//
//  OpalImagePickerRootViewController.swift
//  OpalImagePicker
//
//  Created by Kristos Katsanevas on 1/16/17.
//  Copyright © 2017 Opal Orange LLC. All rights reserved.
//

import UIKit
import Photos

/// Image Picker Root View Controller contains the logic for selecting images. The images are displayed in a `UICollectionView`, and multiple images can be selected.
open class OpalImagePickerRootViewController: UIViewController {

    
    /// Delegate for Image Picker. Notifies when images are selected (done is tapped) or when the Image Picker is cancelled.
    open weak var delegate: OpalImagePickerControllerDelegate?
    
    /// Configuration to change Localized Strings
    open var configuration: OpalImagePickerConfiguration? {
        didSet {
            configuration?.updateStrings = configurationChanged
            if let configuration = self.configuration {
                configurationChanged(configuration)
            }
        }
    }
    
    /// `UICollectionView` for displaying photo library images
    open weak var collectionView: UICollectionView?
    
    
    /// `UICollectionView` for displaying external images
    open weak var externalCollectionView: UICollectionView?
    
    
    /// `UIToolbar` to switch between Photo Library and External Images.
    open lazy var toolbar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        return toolbar
    }()
    
    open var pickerMode: ModalityType? {
        didSet {
            collectionView?.reloadData()
        }
    }
    
    /// Custom Tint Color for overlay of selected images.
    open var selectionTintColor: UIColor? {
        didSet {
            collectionView?.reloadData()
        }
    }
    
    /// Custom Tint Color for selection image (checkmark).
    open var selectionImageTintColor: UIColor? {
        didSet {
            collectionView?.reloadData()
        }
    }
    
    /// Custom selection image (checkmark).
    open var selectionImage: UIImage? {
        didSet {
            collectionView?.reloadData()
        }
    }
    
    /// Allowed Media Types that can be fetched. See `PHAssetMediaType`
    open var allowedMediaTypes: Set<PHAssetMediaType>? {
        didSet {
            updateFetchOptionPredicate()
        }
    }
    
    /// Allowed MediaSubtype that can be fetched. Can be applied as `OptionSet`. See `PHAssetMediaSubtype`
    open var allowedMediaSubtypes: PHAssetMediaSubtype? {
        didSet {
            updateFetchOptionPredicate()
        }
    }
    
    /// Maximum photo selections allowed in picker (zero or fewer means unlimited).
    open var maximumSelectionsAllowed: Int = -1
    
    /// Page size for paging through the Photo Assets in the Photo Library. Defaults to 100. Must override to change this value.
    open let pageSize = 100
    
    var photoAssets: PHFetchResult<PHAsset> = PHFetchResult()
    weak var doneButton: UIBarButtonItem?
    weak var cancelButton: UIBarButtonItem?
    
    internal var collectionViewLayout: OpalImagePickerCollectionViewLayout? {
        return collectionView?.collectionViewLayout as? OpalImagePickerCollectionViewLayout
    }
    
    internal lazy var fetchOptions: PHFetchOptions = {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return fetchOptions
    }()
    
    internal var fetchLimit: Int {
        get {
            return fetchOptions.fetchLimit
        }
        set {
            fetchOptions.fetchLimit = newValue
        }
    }
    
    internal var shouldShowTabs: Bool {
        guard let imagePicker = navigationController as? OpalImagePickerController else { return false }
        return delegate?.imagePickerNumberOfExternalItems?(imagePicker) != nil
    }
    
    fileprivate var photosCompleted = 0
    fileprivate var savedImages: [UIImage] = []
    fileprivate var imagesDict: [IndexPath:UIImage] = [:]
    fileprivate var selectedIndexes: [IndexPath] = []
    fileprivate var showExternalImages = false
    
    fileprivate lazy var cache: NSCache<NSIndexPath, NSData> = {
        let cache = NSCache<NSIndexPath, NSData>()
        cache.totalCostLimit = 128000000 //128 MB
        cache.countLimit = 100 // 100 images
        return cache
    }()
    
    fileprivate weak var rightExternalCollectionViewConstraint: NSLayoutConstraint?
    
    /// Initializer
    public required init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    /// Initializer (Do not use this View Controller in Interface Builder)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("Cannot init \(String(describing: OpalImagePickerRootViewController.self)) from Interface Builder")
    }
    
    fileprivate func setup() {
        let layout = UICollectionViewFlowLayout.init()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 1
        if self.pickerMode == .select {
            fetchPhotos()
            let collectionView = UICollectionView(frame: view.frame, collectionViewLayout: layout)
            setup(collectionView: collectionView)
            view.addSubview(collectionView)
            self.collectionView = collectionView
            var constraints: [NSLayoutConstraint] = []
            constraints += [view.topAnchor.constraint(equalTo: collectionView.topAnchor, constant: 0)]
            constraints += [view.rightAnchor.constraint(equalTo: collectionView.rightAnchor, constant: 0)]
            constraints += [view.leftAnchor.constraint(equalTo: collectionView.leftAnchor, constant: 0)]
            constraints += [view.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 0)]
            
            NSLayoutConstraint.activate(constraints)
        }else{
            let collectionView = UICollectionView(frame: view.frame, collectionViewLayout: layout)
            setup(collectionView: collectionView)
            view.addSubview(collectionView)
            self.externalCollectionView = collectionView
            var constraints: [NSLayoutConstraint] = []
            constraints += [view.topAnchor.constraint(equalTo: collectionView.topAnchor, constant: 0)]
            constraints += [view.rightAnchor.constraint(equalTo: collectionView.rightAnchor, constant: 0)]
            constraints += [view.leftAnchor.constraint(equalTo: collectionView.leftAnchor, constant: 0)]
            constraints += [view.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 0)]
            
            NSLayoutConstraint.activate(constraints)
        }
        
        view.layoutIfNeeded()
    }
    
    fileprivate func setup(collectionView: UICollectionView) {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.allowsMultipleSelection = true
        collectionView.backgroundColor = .white
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isScrollEnabled = true
        collectionView.backgroundColor = UIColor.init(red: 94/255, green: 94/255, blue: 94/255, alpha: 1)
        collectionView.contentInset = UIEdgeInsetsMake(2, 2, 2, 2)
        collectionView.register(UINib(nibName: "PickerCell", bundle: nil), forCellWithReuseIdentifier: "PickerCell")
    }

    
    fileprivate func fetchPhotos() {
        requestPhotoAccessIfNeeded(PHPhotoLibrary.authorizationStatus())
        fetchOptions.fetchLimit = pageSize
        photoAssets = PHAsset.fetchAssets(with: fetchOptions)
        collectionView?.reloadData()
    }
    
    fileprivate func updateFetchOptionPredicate() {
        var predicates: [NSPredicate] = []
        if let allowedMediaTypes = self.allowedMediaTypes {
            let mediaTypesPredicates = allowedMediaTypes.map { NSPredicate(format: "mediaType = %d", $0.rawValue) }
            let allowedMediaTypesPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: mediaTypesPredicates)
            predicates += [allowedMediaTypesPredicate]
        }
        
        if let allowedMediaSubtypes = self.allowedMediaSubtypes {
            let mediaSubtypes = NSPredicate(format: "mediaSubtypes = %d", allowedMediaSubtypes.rawValue)
            predicates += [mediaSubtypes]
        }
        
        if predicates.count > 0 {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            fetchOptions.predicate = predicate
        }
        else {
            fetchOptions.predicate = nil
        }
        fetchPhotos()
    }
    
    /// Load View
    open override func loadView() {
        view = UIView()
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()        
        setup()
        
        navigationItem.title = self.configuration?.navigationTitle ?? NSLocalizedString("Photos", comment: "")
        
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.leftBarButtonItem = cancelButton
        self.cancelButton = cancelButton
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        navigationItem.rightBarButtonItem = doneButton
        self.doneButton = doneButton
    }
    
    func cancelTapped() {
        dismiss(animated: true) { [weak self] in
            guard let imagePicker = self?.navigationController as? OpalImagePickerController else { return }
            self?.delegate?.imagePickerDidCancel?(imagePicker)
        }
    }
    
    func doneTapped() {
        guard let imagePicker = navigationController as? OpalImagePickerController else { return }
        
        let indexPathsForSelectedItems = collectionView?.indexPathsForSelectedItems ?? []
        let externalIndexPaths = externalCollectionView?.indexPathsForSelectedItems ?? []
        guard indexPathsForSelectedItems.count + externalIndexPaths.count > 0 else {
            cancelTapped()
            return
        }
        
        var photoAssets: [PHAsset] = []
        for indexPath in indexPathsForSelectedItems {
            guard indexPath.item < self.photoAssets.count else { continue }
            photoAssets += [self.photoAssets.object(at: indexPath.item)]
        }
        delegate?.imagePicker?(imagePicker, didFinishPickingAssets: photoAssets)
        
        var selectedURLs: [URL] = []
        for indexPath in externalIndexPaths {
            guard let url = delegate?.imagePicker?(imagePicker, imageURLforExternalItemAtIndex: indexPath.item) else { continue }
            selectedURLs += [url]
        }
        delegate?.imagePicker?(imagePicker, didFinishPickingExternalURLs: selectedURLs)
        
        var imagesArray:[UIImage] = []
        for indexPath in selectedIndexes {
            imagesArray.append(imagesDict[indexPath]!)
        }
        
        delegate?.imagePicker?(imagePicker, didFinishPickingImages: imagesArray)
    }
    
    fileprivate func set(image: UIImage?, indexPath: IndexPath, isExternal: Bool) {
        // Only store images if delegate method is implemented
        if let nsDelegate = delegate as? NSObject,
            !nsDelegate.responds(to: #selector(OpalImagePickerControllerDelegate.imagePicker(_:didFinishPickingImages:))) {
            return
        }
        
        let key = IndexPath(item: indexPath.item, section: 0)
        imagesDict[key] = image
        if(image != nil){
            selectedIndexes.append(key)
        }else{
            selectedIndexes = selectedIndexes.filter() { $0 != key}
        }
    }
    
    fileprivate func get(imageForIndexPath indexPath: IndexPath, isExternal: Bool) -> UIImage? {
        let key = IndexPath(item: indexPath.item-1, section: 0)
        return imagesDict[key]
    }
    
    fileprivate func fetchNextPageIfNeeded(indexPath: IndexPath) {
        guard indexPath.item == fetchLimit-1 else { return }
        
        let oldFetchLimit = fetchLimit
        fetchLimit += pageSize
        photoAssets = PHAsset.fetchAssets(with: fetchOptions)
        
        var indexPaths: [IndexPath] = []
        for i in oldFetchLimit..<photoAssets.count {
            indexPaths += [IndexPath(item: i, section: 0)]
        }
        collectionView?.insertItems(at: indexPaths)
    }
    
    fileprivate func requestPhotoAccessIfNeeded(_ status: PHAuthorizationStatus) {
        guard status == .notDetermined else { return }
        PHPhotoLibrary.requestAuthorization { [weak self] (authorizationStatus) in
            DispatchQueue.main.async { [weak self] in
                self?.photoAssets = PHAsset.fetchAssets(with: self?.fetchOptions)
                self?.collectionView?.reloadData()
            }
        }
    }
    
    fileprivate func configurationChanged(_ configuration: OpalImagePickerConfiguration) {
        if let navigationTitle = configuration.navigationTitle {
            navigationItem.title = navigationTitle
        }
        
        if let librarySegmentTitle = configuration.librarySegmentTitle {
            navigationItem.title = librarySegmentTitle
        }
    }
}

//MARK: - Collection View Delegate

extension OpalImagePickerRootViewController: UICollectionViewDelegate {
    /// Collection View did select item at `IndexPath`
    ///
    /// - Parameters:
    ///   - collectionView: the `UICollectionView`
    ///   - indexPath: the `IndexPath`
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if selectedIndexes.index(of: indexPath) == nil {
            guard let cell = collectionView.cellForItem(at: indexPath) as? PickerCell,
                let image = cell.imageView?.image else { return }
            set(image: image, indexPath: indexPath, isExternal: collectionView == self.externalCollectionView)
        } else {
            set(image: nil, indexPath: indexPath, isExternal: collectionView == self.externalCollectionView)
        }
        collectionView.reloadData()
    }
    
    public func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard let cell = collectionView.cellForItem(at: indexPath) as? PickerCell,
            cell.imageView?.image != nil else { return false }
        guard maximumSelectionsAllowed > 0 else { return true }
                
        if maximumSelectionsAllowed <= selectedIndexes.count {
            //We exceeded maximum allowed, so alert user. Don't allow selection
            let message = configuration?.maximumSelectionsAllowedMessage ?? NSLocalizedString("You cannot select more than \(maximumSelectionsAllowed) images. Please deselect another image before trying to select again.", comment: "You cannot select more than (x) images. Please deselect another image before trying to select again. (OpalImagePicker)")
            let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
            let okayString = configuration?.okayString ?? NSLocalizedString("OK", comment: "OK")
            let action = UIAlertAction(title: okayString, style: .cancel, handler: nil)
            alert.addAction(action)
            present(alert, animated: true, completion: nil)
            return false
        }
        return true
    }
}

//MARK: - Collection View Data Source

extension OpalImagePickerRootViewController: UICollectionViewDataSource {
    
    
    /// Returns Collection View Cell for item at `IndexPath`
    ///
    /// - Parameters:
    ///   - collectionView: the `UICollectionView`
    ///   - indexPath: the `IndexPath`
    /// - Returns: Returns the `UICollectionViewCell`
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if(self.pickerMode == .select) {
            return photoAssetCollectionView(collectionView, cellForItemAt: indexPath)
        }
        else {
            return externalCollectionView(collectionView, cellForItemAt: indexPath)
        }
    }
    
    fileprivate func photoAssetCollectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        fetchNextPageIfNeeded(indexPath: indexPath)
        
        guard let layoutAttributes = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath),
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PickerCell", for: indexPath) as? PickerCell else { return UICollectionViewCell() }
        let photoAsset = photoAssets.object(at: indexPath.item)
        let index = selectedIndexes.index(of: indexPath)
        cell.indexPath = indexPath
        cell.photoAsset = photoAsset
        cell.size = layoutAttributes.frame.size
        cell.cache = cache
        cell.setup(index: index)
        
        return cell
    }
    
    fileprivate func externalCollectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let imagePicker = navigationController as? OpalImagePickerController,
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PickerCell", for: indexPath) as? PickerCell else { return UICollectionViewCell() }
        if let url = delegate?.imagePicker?(imagePicker, imageURLforExternalItemAtIndex: indexPath.item) {
            let index = selectedIndexes.index(of: indexPath)
            cell.cache = cache
            cell.indexPath = indexPath
            cell.url = url
            cell.setup(index: index)
        } else {
            assertionFailure("You need to implement `imagePicker(_:imageURLForExternalItemAtIndex:)` in your delegate.")
        }
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == self.collectionView {
            return photoAssets.count
        }
        else if let imagePicker = navigationController as? OpalImagePickerController,
            let numberOfItems = delegate?.imagePickerNumberOfExternalItems?(imagePicker) {
            return numberOfItems
        }
        else {
            assertionFailure("You need to implement `imagePickerNumberOfExternalItems(_:)` in your delegate.")
            return 0
        }
    }
}

extension OpalImagePickerRootViewController: UICollectionViewDelegateFlowLayout{
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let side = (collectionView.bounds.size.width/3)-2
        return CGSize.init(width: side, height: side)
    }
}
