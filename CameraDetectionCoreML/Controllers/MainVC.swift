//
//  ViewController.swift
//  CameraDetectionCoreML
//
//  Created by Arsalan majlesi on 7/7/21.
//

import UIKit
import AVFoundation
import CoreML
import Vision

enum FlashState {
    case on,off
}

class MainVC: UIViewController {

    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var confidenceLbl: UILabel!
    @IBOutlet weak var flashBtn: UIButton!
    @IBOutlet weak var predictionLbl: UILabel!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    var captureSession : AVCaptureSession!
    var cameraOutput : AVCapturePhotoOutput!
    var previewLayer : AVCaptureVideoPreviewLayer!
    var speechSynthesizer = AVSpeechSynthesizer()
    
    var photoData : Data!
    var flashControlState : FlashState = .off
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer.frame = cameraView.bounds
        speechSynthesizer.delegate = self
        loadingIndicator.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let tapGestureRec = UITapGestureRecognizer(target: self, action: #selector(onTapRecCapturePhoto))
        
        
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .hd1920x1080
        
        let backCamera = AVCaptureDevice.default(for: .video)
        do{
            let cameraInput = try AVCaptureDeviceInput(device: backCamera!)
            if captureSession.canAddInput(cameraInput){
                captureSession.addInput(cameraInput)
                
                cameraOutput = AVCapturePhotoOutput()
                if captureSession.canAddOutput(cameraOutput){
                    captureSession.addOutput(cameraOutput)
                    
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                    previewLayer.videoGravity = .resizeAspect
                    previewLayer.connection?.videoOrientation = .portrait
                    
                    cameraView.layer.addSublayer(previewLayer)
                    cameraView.addGestureRecognizer(tapGestureRec)
                    captureSession.startRunning()
                }
            }
        }catch {
            debugPrint(error)
        }
    }
    @IBAction func flashBtnPressed(_ sender: Any) {
        switch flashControlState {
        case .off:
            flashBtn.setTitle("Flash On", for: .normal)
            flashControlState = .on
        case .on:
            flashBtn.setTitle("Flash Off", for: .normal)
            flashControlState = .off
        }
    }
    
    @objc func onTapRecCapturePhoto(){
        self.cameraView.isUserInteractionEnabled = false
        
        if imgView.image != nil {
            self.loadingIndicator.isHidden = false
            self.loadingIndicator.startAnimating()
        }
        confidenceLbl.text = ""
        predictionLbl.text = ""
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String:previewPixelType,kCVPixelBufferWidthKey as String: 120, kCVPixelBufferHeightKey as String: 120]
        
        if flashControlState == .off {
            settings.flashMode = .off
        } else {
            settings.flashMode = .on
        }
        
        //Alternative way
//        settings.previewPhotoFormat = settings.embeddedThumbnailPhotoFormat
        settings.previewPhotoFormat = previewFormat
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func VNCoreMLHandler(request:VNRequest,error:Error?){
        guard let results = request.results as? [VNClassificationObservation] else { return }
        
        for classification in results{
            if classification.confidence < 0.5{
                let failureString = "I'm not sure what this is, Please try again"
                predictionLbl.text = failureString
                confidenceLbl.text = ""
                speakOutLoud(theString: failureString)
                break
            } else {
                let confidence = Int(classification.confidence * 100)
                let speechText = "This is a \(classification.identifier) and i'm \(confidence)% sure"
                predictionLbl.text = classification.identifier
                confidenceLbl.text = "CONFIDENCE: \(confidence)%"
                speakOutLoud(theString: speechText)
                break
            }
        }
    }
    
    func speakOutLoud(theString string:String){
        let utterance = AVSpeechUtterance(string: string)
        speechSynthesizer.speak(utterance)
    }
}

extension MainVC : AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil{
            debugPrint(error as Any)
            return
        }
        photoData = photo.fileDataRepresentation()
        
        do{
            let model = try VNCoreMLModel(for: SqueezeNet().model)
            let request = VNCoreMLRequest(model: model, completionHandler: VNCoreMLHandler)
            let handler = VNImageRequestHandler(data: photoData)
            try handler.perform([request])
        } catch {
            debugPrint(error)
        }
        if imgView.image == nil {
            self.loadingIndicator.isHidden = false
            self.loadingIndicator.startAnimating()
        }
        let img = UIImage(data: photoData)
        imgView.image = img
    }
}

extension MainVC : AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.cameraView.isUserInteractionEnabled = true
        self.loadingIndicator.stopAnimating()
        self.loadingIndicator.isHidden = true
    }
}
