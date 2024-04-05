//
//  Detector.swift
//  BiometricTimekeeper
//
//  Created by Luke Nguyen on 05/04/2024.
//

import AppKit
import Vision
import AVFoundation

extension MainVC {
    func setupDetector() {
        guard let modelURL = Bundle.main.url(forResource: "Outcubator", withExtension: "mlmodelc") else { return }
        
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let recognitions = VNCoreMLRequest(model: visionModel, completionHandler: detectionDidComplete)
            self.requests = [recognitions]
        } catch let error {
            print(error)
        }
    }
    
    func detectionDidComplete(request: VNRequest, error: Error?) {
        DispatchQueue.main.async(execute: {
            if let results = request.results {
                self.extractDetections(results)
            }
        })
    }
    
    func extractDetections(_ results: [VNObservation]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionLayer?.sublayers = nil
        
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else { continue }
            
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(screenRect.size.width), Int(screenRect.size.height))
            let transformedBounds = CGRect(x: objectBounds.minX, y: screenRect.size.height - objectBounds.maxY, width: objectBounds.maxX - objectBounds.minX, height: objectBounds.maxY - objectBounds.minY)
            
            let topLabelObservation = objectObservation.labels[0]
           
            let boxLayer = self.drawBoundingBox(transformedBounds)
            let textLayer = self.drawLabel(transformedBounds, identifier: topLabelObservation.identifier, confidence: topLabelObservation.confidence)
            
//            if topLabelObservation.confidence > 0.8 {
//
//            }
            
            detectionLayer?.addSublayer(textLayer)
            detectionLayer?.addSublayer(boxLayer)
        }
        
        CATransaction.commit()
    }
    
    func setupLayers() {
        detectionLayer = CALayer()
        detectionLayer?.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        DispatchQueue.main.async { [weak self] in
            guard let detectionLayer = self?.detectionLayer else { return }
            self?.view.layer?.addSublayer(detectionLayer)
        }
    }
    
    func updateLayers() {
        detectionLayer?.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
    }
    
    func drawBoundingBox(_ bounds: CGRect) -> CALayer {
        let boxLayer = CALayer()
        boxLayer.frame = bounds
        boxLayer.borderWidth = 3.0
        boxLayer.borderColor = NSColor.systemPink.cgColor
        boxLayer.cornerRadius = 4
        return boxLayer
    }
    
    func drawLabel(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        let textFrame: CGFloat = 100
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:  %.2f", confidence))
        let largeFont = NSFont(name: "Helvetica", size: 30.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont, NSAttributedString.Key.foregroundColor: NSColor.systemPink ], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.frame = CGRect(x: 0, y: 0, width: textFrame, height: textFrame)
        textLayer.position = CGPoint(x: view.bounds.minX + textFrame, y: view.bounds.maxY - textFrame)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 1, height: 1)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        return textLayer
    }
    
}
