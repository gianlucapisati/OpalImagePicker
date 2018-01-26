//
//  ViewController.swift
//  OpalImagePicker
//
//  Created by Kristos Katsanevas on 1/15/17.
//  Copyright © 2017 Opal Orange LLC. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var urls:[URL] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
        urls.append(URL.init(string: "https://thumbs.dreamstime.com/b/infinito-del-segno-34338284.jpg")!)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func didTapOpenPicker(_ sender: Any) {
        let imagePicker = OpalImagePickerController()
        imagePicker.imagePickerDelegate = self
        imagePicker.pickerMode = .reorder
        imagePicker.maximumSelectionsAllowed = 10
        let configuration = OpalImagePickerConfiguration()
        configuration.navigationTitle = NSLocalizedString("Pippo", comment: "")
        configuration.maximumSelectionsAllowedMessage = NSLocalizedString("You cannot select that many images!", comment: "")
        imagePicker.configuration = configuration
        self.present(imagePicker, animated: true, completion: nil)
    }
}


extension ViewController:OpalImagePickerControllerDelegate {
    func imagePickerDidCancel(_ picker: OpalImagePickerController){
        print("cancel")
    }
    func imagePicker(_ picker: OpalImagePickerController, didFinishPickingImages images: [UIImage]){
        print("\(images)")
    }
    func imagePickerNumberOfExternalItems(_ picker: OpalImagePickerController) -> Int{
        return self.urls.count
    }
    func imagePicker(_ picker: OpalImagePickerController, imageURLforExternalItemAtIndex index: Int) -> URL?{
        return self.urls[index]
    }
    func imagePickerTitleForExternalItems(_ picker: OpalImagePickerController) -> String{
        return "Store Images"
    }
    func imagePicker(_ picker: OpalImagePickerController, didFinishPickingExternalURLs urls: [URL]){
        print("\(urls)")
    }
}
