//
//  ViewController.swift
//  DepthCaptureDemo
//
//  Created by Aleksei Karpov on 2024-11-01.
//

import UIKit
import AVFoundation


extension UIImage {
    func withOrientation(_ orientation: UIImage.Orientation) -> UIImage {
        guard let cgImage = self.cgImage else { return self }
        return UIImage(cgImage: cgImage, scale: self.scale, orientation: orientation)
    }
}

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    // UI elements
    var captureButton: UIButton!
    var imageView: UIImageView!

    // Capture session and outputs
    var captureSession: AVCaptureSession!
    var depthDataOutput: AVCaptureDepthDataOutput!
    var photoOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up UI components
        setupUI()
        checkPermissionsAndSetupSession()
    }

    func setupUI() {
        // Set up image view
        imageView = UIImageView(frame: view.bounds)
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)

        // Set up capture button
        captureButton = UIButton(type: .system)
        captureButton.setTitle("Capture Depth", for: .normal)
        captureButton.addTarget(self, action: #selector(startCapture), for: .touchUpInside)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(captureButton)

        NSLayoutConstraint.activate([
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    func checkPermissionsAndSetupSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCaptureSession()
                    }
                }
            }
        default:
            print("Camera access denied")
        }
    }
    
    func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back) else {
            print("LiDAR camera not available")
            return
        }

        
        // Begin the device configuration.
        do {
            try device.lockForConfiguration()
            device.activeFormat = device.formats.last(where: { !$0.supportedDepthDataFormats.isEmpty })!
            device.unlockForConfiguration()
        } catch {
            print("Failed to lock device for configuration: \(error)")
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            photoOutput = AVCapturePhotoOutput()
            depthDataOutput = AVCaptureDepthDataOutput()
            
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }
            
            if captureSession.canAddOutput(depthDataOutput) {
                captureSession.addOutput(depthDataOutput)
            }
            
            // Set depth data delivery if supported
            if photoOutput.isDepthDataDeliverySupported {
                photoOutput.isDepthDataDeliveryEnabled = true
            } else {
                print("Depth data delivery is not supported on this device.")
            }
            
            // Start session and add live preview layer
            setupLivePreview()
            
            captureSession.startRunning()
        } catch {
            print("Error setting up capture session: \(error)")
        }
    }
    
    func setupLivePreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0) // Add behind other UI elements
    }

    @objc func startCapture() {
        // Configure settings for capturing depth data
        var photoSettings: AVCapturePhotoSettings
        if  photoOutput.availablePhotoPixelFormatTypes.contains(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            photoSettings = AVCapturePhotoSettings(format: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ])
        } else {
            photoSettings = AVCapturePhotoSettings()
        }
        
        // Set depth data delivery only if it's enabled
        if photoOutput.isDepthDataDeliveryEnabled {
            photoSettings.isDepthDataDeliveryEnabled = true
            print("Depth data delivery is enabled on this device!!!!")
        } else {
            print("Depth data delivery is not enabled on this device.")
        }

        // Capture the photo
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Error capturing photo: \(String(describing: error))")
            return
        }
        
        // Retrieve color image
        if let pixelBuffer = photo.pixelBuffer {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let colorImage = UIImage(ciImage: ciImage)
            
            // Process depth data and combine with color image
            if let depthData = photo.depthData {
                printCalibrationData(from: depthData)
                handleDepthData(depthData, colorImage: colorImage)
            } else {
                print("No depth data in photo")
                imageView.image = colorImage.withOrientation(.right) // Display color image alone if no depth data
            }
        }
    }

    func handleDepthData(_ depthData: AVDepthData, colorImage: UIImage) {
        // Convert depth data and lock buffer
        let depthMap = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32).depthDataMap
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) } // Ensure unlock on exit
        
        // Get depth dimensions and pointer
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard let depthPointer = CVPixelBufferGetBaseAddress(depthMap)?.assumingMemoryBound(to: Float32.self) else {
            print("Failed to get depth data pointer.")
            return
        }
        
        // Calculate min and max depth values, ignoring non-finite values
        var minDepth: Float = .greatestFiniteMagnitude
        var maxDepth: Float = -.greatestFiniteMagnitude
        for i in 0..<width * height {
            let depthValue = depthPointer[i]
            if depthValue.isFinite {
                minDepth = min(minDepth, depthValue)
                maxDepth = max(maxDepth, depthValue)
            }
        }
        
        // Check for valid depth range
        guard minDepth < maxDepth else {
            print("No valid depth data found.")
            imageView.image = colorImage
            return
        }
        
        // Normalize depth values to grayscale
        let depthRange = maxDepth - minDepth
        print("Depth max: \(maxDepth)")
        print("Depth min: \(minDepth)")
        var depthPixels = [UInt8](repeating: 0, count: width * height)
        for i in 0..<width * height {
            let depthValue = depthPointer[i]
            if depthValue.isFinite {
                let normalizedDepth = (depthValue - minDepth) / depthRange
                depthPixels[i] = UInt8(normalizedDepth * 255)
            }
        }
        
        // Create grayscale UIImage from depth data
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        guard let provider = CGDataProvider(data: Data(depthPixels) as CFData),
              let depthCGImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width, space: colorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            print("Failed to create CGImage from depth data.")
            return
        }
        
        let depthImage = UIImage(cgImage: depthCGImage)
        
        // Combine color and depth images
        UIGraphicsBeginImageContext(colorImage.size)
        colorImage.draw(in: CGRect(origin: .zero, size: colorImage.size))
        depthImage.draw(in: CGRect(origin: .zero, size: colorImage.size), blendMode: .overlay, alpha: 0.8)
        let combinedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Display combined image
        imageView.image = combinedImage?.withOrientation(.right)
    }
    
    func printCalibrationData(from depthData: AVDepthData) {
        guard let calibrationData = depthData.cameraCalibrationData else {
            print("No camera calibration data available.")
            return
        }
        
        print("Camera Calibration Data:")
        print("Intrinsic Matrix: \(calibrationData.intrinsicMatrix)")
        print("Reference Dimensions: \(calibrationData.intrinsicMatrixReferenceDimensions)")
        print("Focal Length X: \(calibrationData.intrinsicMatrix[0, 0])")
        print("Focal Length Y: \(calibrationData.intrinsicMatrix[1, 1])")
        print("Principal Point X: \(calibrationData.intrinsicMatrix[2, 0])")
        print("Principal Point Y: \(calibrationData.intrinsicMatrix[2, 1])")
    }
}
