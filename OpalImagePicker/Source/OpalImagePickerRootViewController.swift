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
        if self.pickerMode == .select {
            fetchPhotos()
            let collectionView = UICollectionView(frame: view.frame, collectionViewLayout: OpalImagePickerCollectionViewLayout())
            setup(collectionView: collectionView)
            view.addSubview(collectionView)
            
            self.collectionView = collectionView
            var constraints: [NSLayoutConstraint] = []
            constraints += [view.topAnchor.constraint(equalTo: (collectionView.topAnchor))]
            constraints += [view.rightAnchor.constraint(equalTo: (collectionView.rightAnchor))]
            
            //Lower priority to override left constraint for animations
            let leftCollectionViewConstraint = view.leftAnchor.constraint(equalTo: (collectionView.leftAnchor))
            leftCollectionViewConstraint.priority = 999
            constraints += [leftCollectionViewConstraint]
            
            constraints += [view.bottomAnchor.constraint(equalTo: (collectionView.bottomAnchor))]
            NSLayoutConstraint.activate(constraints)
        }else{
            let collectionView = UICollectionView(frame: view.frame, collectionViewLayout: OpalImagePickerCollectionViewLayout())
            setup(collectionView: collectionView)
            view.addSubview(collectionView)
            
            self.externalCollectionView = collectionView
            var constraints: [NSLayoutConstraint] = []
            constraints += [view.topAnchor.constraint(equalTo: (externalCollectionView?.topAnchor)!)]
            constraints += [view.rightAnchor.constraint(equalTo: (externalCollectionView?.rightAnchor)!)]
            
            //Lower priority to override left constraint for animations
            let leftCollectionViewConstraint = view.leftAnchor.constraint(equalTo: (externalCollectionView?.leftAnchor)!)
            leftCollectionViewConstraint.priority = 999
            constraints += [leftCollectionViewConstraint]
            
            constraints += [view.bottomAnchor.constraint(equalTo: (externalCollectionView?.bottomAnchor)!)]
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
        collectionView.register(PickerCell.self, forCellWithReuseIdentifier: "PickerCell")
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
        
        navigationItem.title = configuration?.navigationTitle ?? NSLocalizedString("Photos", comment: "")
        
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
        guard let cell = collectionView.cellForItem(at: indexPath) as? ImagePickerCollectionViewCell,
            let image = cell.imageView?.image else { return }
        set(image: image, indexPath: indexPath, isExternal: collectionView == self.externalCollectionView)
        let index = selectedIndexes.index(of: indexPath)
        let number = index != nil ? index!+1 : nil
        cell.number = number
        cell.setup(number: number)
    }
    
    
    /// Collection View did de-select item at `IndexPath`
    ///
    /// - Parameters:
    ///   - collectionView: the `UICollectionView`
    ///   - indexPath: the `IndexPath`
    public func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? ImagePickerCollectionViewCell else {return}
        set(image: nil, indexPath: indexPath, isExternal: collectionView == self.externalCollectionView)
        let index = selectedIndexes.index(of: indexPath)
        let number = index != nil ? index!+1 : nil
        cell.number = number
        cell.setup(number: number)
        
        collectionView.reloadItems(at: selectedIndexes)
        
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImagePickerCollectionViewCell.reuseId, for: indexPath) as? ImagePickerCollectionViewCell else { return UICollectionViewCell() }
        let photoAsset = photoAssets.object(at: indexPath.item)
        let index = selectedIndexes.index(of: indexPath)
        cell.photoAsset = photoAsset
        cell.size = layoutAttributes.frame.size
        let number = index != nil ? index!+1 : nil
        cell.number = number
        cell.setup(number: number)
        
        
        return cell
    }
    
    fileprivate func externalCollectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let imagePicker = navigationController as? OpalImagePickerController,
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PickerCell", for: indexPath) as? PickerCell else { return UICollectionViewCell() }
        if let url = delegate?.imagePicker?(imagePicker, imageURLforExternalItemAtIndex: indexPath.item) {
            let index = selectedIndexes.index(of: indexPath)
            cell.setup(index: index)
        }
        else {
            assertionFailure("You need to implement `imagePicker(_:imageURLForExternalItemAtIndex:)` in your delegate.")
        }
        
        return cell
    }
    
    /// Returns the number of items in a given section
    ///
    /// - Parameters:
    ///   - collectionView: the `UICollectionView`
    ///   - section: the given section of the `UICollectionView`
    /// - Returns: Returns an `Int` for the number of rows.
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
