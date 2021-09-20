//
//  CameraViewModel.swift
//  SmartCamera
//
//  Created by Anton on 07.08.2021.
//

import AVFoundation
import SwiftUI
import Vision
import CoreML

class CameraViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var videoOutput = AVCaptureVideoDataOutput()
    @Published var preview: AVCaptureVideoPreviewLayer!
    
    @Published var isTaken: Bool = false
    @Published var photoData = Data(count: 0)
    
    @Published var alert: Bool = false
    @Published var isSaved: Bool = false
    @Published var result: String = ""
    
    @Published var name: String = "MobileNet"
    var model: MLModel {
        do {
            switch name {
            case "MobileNet":
                return try MobileNetV2(configuration: MLModelConfiguration()).model
            case "Food":
                return try Food101(configuration: MLModelConfiguration()).model
            case "Flowers":
                return try Oxford102(configuration: MLModelConfiguration()).model
            default:
                return try MobileNetV2(configuration: MLModelConfiguration()).model
            }
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }
    
    //MARK: SetUp & Authorization
    
    func setUp() {
        do {
            self.session.beginConfiguration()
            
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            let input = try AVCaptureDeviceInput(device: device!)
            
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            
            videoOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
            self.session.addOutput(self.videoOutput)
            
            self.session.commitConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func checkAuthorization() {
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { status in
                if status {
                    self.setUp()
                }
            }
        case .denied:
            self.alert.toggle()
            return
        default:
            return
            
        }
    }
    
    //MARK: Delegate Methods
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("unable to get image from sample buffer")
            return
        }
        
        self.updateClassifications(in: pixelBuffer)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            return
        }
        print("pic taken...")
        
        guard let imageData = photo.fileDataRepresentation() else { return}
        self.photoData = imageData
    }
    
    //MARK: Vision & CoreML
    var classificationRequest: VNCoreMLRequest {
        do {
            let model = try VNCoreMLModel(for: model)
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }
    
    func updateClassifications(in image: CVPixelBuffer) {
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .right)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
    
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                return
            }
            
            let classifications = results as! [VNClassificationObservation]
            
            if !classifications.isEmpty {
                if classifications.first!.confidence > 0.5 {
                    let identifier = classifications.first?.identifier ?? "Result"
                    if let firstResult = identifier.components(separatedBy: ", ").first {
                        self.result = firstResult.capitalized
                    }
                }
            }
        }
    }
    
    //MARK: Camera Functionalities
    
    func capturePhoto() {
        self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        
        DispatchQueue.global(qos: .background).async {
            self.session.stopRunning()
            
            DispatchQueue.main.async {
                withAnimation {
                    self.isTaken.toggle()
                }
            }
        }
    }
    
    func retakePhoto() {
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
            
            DispatchQueue.main.async {
                withAnimation {
                    self.isTaken.toggle()
                    
                    self.isSaved = false
                    self.photoData = Data(count: 0)
                }
            }
        }
    }
    
    func savePhoto() {
        guard let image = UIImage(data: self.photoData) else { return }
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        self.isSaved = true
        
        print("saved successfully")
        retakePhoto()
    }
    
    func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        guard device.hasTorch else { print("Torch isn't available"); return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            if on { try device.setTorchModeOn(level: 1) }
            device.unlockForConfiguration()
        } catch {
            print("Torch can't be used")
        }
    }
}


//MARK: UIViewRepresentable

struct CameraPreview: UIViewRepresentable {
    
    @ObservedObject var camera: CameraViewModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
        camera.preview.frame = view.frame
        
        camera.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(camera.preview)
        
        camera.session.startRunning()
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
