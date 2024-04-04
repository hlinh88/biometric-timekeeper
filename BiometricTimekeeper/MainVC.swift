//
//  MainVC.swift
//  BiometricTimekeeper
//
//  Created by Luke Nguyen on 04/04/2024.
//

import AppKit
import SwiftUI
import AVFoundation
import Vision

class MainVC: NSViewController {
    private var permissionGranted = false
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var previewLayer = AVCaptureVideoPreviewLayer()
    var screenRect: CGRect! = NSScreen.main?.frame
    
    private var videoDataOutput = AVCaptureVideoDataOutput()
    
    private var drawings: [CAShapeLayer] = []
    
    
    override func viewDidLoad() {
        checkPermission()
        
        sessionQueue.async { [unowned self] in
            guard permissionGranted else { return }
            
            self.setupCaptureSession()
            
            self.captureSession.startRunning()
        }
    }
    
    override func viewWillAppear() {
        self.clearDrawings()
    }
    
    override func viewWillDisappear() {
        self.clearDrawings()
    }
    
    // MARK: - Check camera permission
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            
        case .notDetermined:
            requestPermission()
            
        default:
            permissionGranted = false
        }
    }
    
    func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    // MARK: - Setup capture session
    func setupCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,for: .video, position: .back) else { return }
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        
        guard captureSession.canAddInput(videoDeviceInput) else { return }
        captureSession.addInput(videoDeviceInput)
        
        screenRect = NSScreen.main?.frame
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        
        videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString): NSNumber(value: kCVPixelFormatType_32BGRA)] as [String: Any]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        captureSession.addOutput(videoDataOutput)
        
        videoDataOutput.connection(with: .video)?.videoOrientation = .portrait
        
        DispatchQueue.main.async { [weak self] in
            self?.view.layer?.addSublayer(self!.previewLayer)
        }
    }
    
    // MARK: - Handle face recognition
    func detectFace(image: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceLandmarksRequest { vnRequest, error in
            DispatchQueue.main.async { [weak self] in
                if let faceResults = vnRequest.results as? [VNFaceObservation], faceResults.count > 0 {
                    self?.handleFaceDetectionResults(observedFaces: faceResults)
                } else {
                    self?.clearDrawings()
                }
            }
        }
        
        let imageResultHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .up)
        try? imageResultHandler.perform([faceDetectionRequest])
    }
    
    private func handleFaceDetectionResults(observedFaces: [VNFaceObservation]) {
        clearDrawings()
        
        let faceBoundingBoxes: [CAShapeLayer] = observedFaces.map { observedFace in
            let boundingBox = observedFace.boundingBox
            
            let faceBoundingBoxOnScreen = previewLayer.layerRectConverted(fromMetadataOutputRect: boundingBox)
            let faceBoundingBoxPath = CGPath(rect: faceBoundingBoxOnScreen, transform: nil)
            print("✅ Path: \(faceBoundingBoxPath)")
            let faceBoundingBoxShape = CAShapeLayer()
            
            faceBoundingBoxShape.path = faceBoundingBoxPath
            faceBoundingBoxShape.fillColor = NSColor.clear.cgColor
            faceBoundingBoxShape.strokeColor = NSColor.green.cgColor
            faceBoundingBoxShape.lineWidth = 3
            
            return faceBoundingBoxShape
        }
        
        faceBoundingBoxes.forEach { faceBoundingBox in
            DispatchQueue.main.async { [weak self] in
                self?.view.layer?.addSublayer(faceBoundingBox)
                self?.drawings = faceBoundingBoxes
            }
        }
    }
    
    private func clearDrawings() {
        drawings.forEach({ $0.removeFromSuperlayer() })
        drawings.removeAll()
    }
}

extension MainVC: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("Unable to get image from sample buffer")
            return
        }
        
        detectFace(image: frame)
    }
}





struct HostedViewController: NSViewControllerRepresentable {
    
    func makeNSViewController(context: Context) -> some NSViewController {
        return MainVC()
    }
    
    func updateNSViewController(_ nsViewController: NSViewControllerType, context: Context) {
        
    }
    
}
