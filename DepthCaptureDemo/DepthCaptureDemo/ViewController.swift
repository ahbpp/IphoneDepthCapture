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

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate, UITextFieldDelegate {

    // UI elements
    var captureButton: UIButton!
    var imageView: UIImageView!
    var objectNameTextField: UITextField!
    var topFrameView: UIView!
    var bottomFrameView: UIView!
    
    // Capture session and outputs
    var captureSession: AVCaptureSession!
    var depthDataOutput: AVCaptureDepthDataOutput!
    var photoOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    let cameraMotion = CameraMotion()
    let cameraCapturedDataSaver = CameraCapturedDataSaver()
    


    override func viewDidLoad() {
        super.viewDidLoad()
        
        cameraMotion.startTracking() // Start motion tracking
        // Set up UI components
        setupUI()
        checkPermissionsAndSetupSession()
        
        
        // Add tap gesture recognizer to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
        // Set the text field delegate
        objectNameTextField.delegate = self
    }

    func setupUI() {

        // Set up top frame view
        topFrameView = UIView()
        topFrameView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        topFrameView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topFrameView)

        // Set up bottom frame view
        bottomFrameView = UIView()
        bottomFrameView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        bottomFrameView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomFrameView)

        // Set up image view to fill in between the frames
        imageView = UIImageView(frame: view.bounds)
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)
        view.sendSubviewToBack(imageView) // Keep image view behind other UI elements

        // Set up capture button with a white background on the bottom frame
        captureButton = UIButton(type: .custom)
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 2
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.backgroundColor = .white.withAlphaComponent(0.8)
        captureButton.setTitleColor(.black, for: .normal)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(startCapture), for: .touchUpInside)
        bottomFrameView.addSubview(captureButton) // Add button to bottom frame view

        // Set up the object name text field at the center of the top frame
        objectNameTextField = UITextField()
        objectNameTextField.placeholder = "Enter Object Name"
        objectNameTextField.borderStyle = .roundedRect
        objectNameTextField.backgroundColor = UIColor.darkGray.withAlphaComponent(0.8)
        objectNameTextField.textColor = .white
        objectNameTextField.textAlignment = .center
        objectNameTextField.font = UIFont.systemFont(ofSize: 16)
        objectNameTextField.translatesAutoresizingMaskIntoConstraints = false
        topFrameView.addSubview(objectNameTextField) // Add text field to top frame view
        
        
        // Share button
        let shareButton = UIButton(type: .system)
        var shareButtonConfig = UIButton.Configuration.filled()
        shareButtonConfig.baseBackgroundColor = .systemGray5
        shareButtonConfig.baseForegroundColor = .systemBlue
        shareButtonConfig.cornerStyle = .capsule // Rounded style
        shareButtonConfig.image = UIImage(systemName: "square.and.arrow.up") // Native share icon
//        shareButtonConfig.title = "Share"
//        shareButtonConfig.imagePadding = 8
//        shareButtonConfig.imagePlacement = .leading
        shareButton.configuration = shareButtonConfig
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.addTarget(self, action: #selector(shareFiles), for: .touchUpInside)
        bottomFrameView.addSubview(shareButton)

        // Set up layout constraints
        NSLayoutConstraint.activate([
            // Set up top frame
            topFrameView.topAnchor.constraint(equalTo: view.topAnchor),
            topFrameView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topFrameView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topFrameView.heightAnchor.constraint(equalToConstant: 100),

            // Set up bottom frame
            bottomFrameView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomFrameView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFrameView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFrameView.heightAnchor.constraint(equalToConstant: 120),

            // Center the text field in the top frame
            objectNameTextField.centerXAnchor.constraint(equalTo: topFrameView.centerXAnchor),
            objectNameTextField.bottomAnchor.constraint(equalTo: topFrameView.bottomAnchor, constant: -10),
            objectNameTextField.widthAnchor.constraint(equalToConstant: 200),
            objectNameTextField.heightAnchor.constraint(equalToConstant: 30),

            // Center capture button in the bottom frame
            captureButton.centerXAnchor.constraint(equalTo: bottomFrameView.centerXAnchor),
            captureButton.centerYAnchor.constraint(equalTo: bottomFrameView.centerYAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),
            
            
            // Layout for share button
            shareButton.centerXAnchor.constraint(equalTo: bottomFrameView.leftAnchor, constant: 70),
            shareButton.centerYAnchor.constraint(equalTo: bottomFrameView.centerYAnchor),
            shareButton.widthAnchor.constraint(equalToConstant: 40),
            shareButton.heightAnchor.constraint(equalToConstant: 40),
            
            
            
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
        guard let pixelBuffer = photo.pixelBuffer, let depthData = photo.depthData, error == nil else {
            print("Error capturing photo: \(String(describing: error))")
            return
        }
                
        // Capture current orientation and acceleration
        let orientationData = cameraMotion.getRelativeOrientation()
        let accelerationData = cameraMotion.getRelativeAcceleration()
        let motionMetadata = MotionMetadata(orientationData: orientationData,
                                            accelerationData: accelerationData)
        
        let cameraCaptureData = createCameraCapturedData(pixelBuffer: pixelBuffer,
                                                         depthData: depthData,
                                                         motionMetadata: motionMetadata)
        
        // Define folder path and prefix
        let objectName = objectNameTextField.text?.isEmpty == true ? "DefaultObject" : objectNameTextField.text!
        let filePath = getObjectFolderPath(folderName: objectName)
        let timestamp = Int(Date().timeIntervalSince1970)
        let prefix = "frame_\(timestamp)"
        cameraCapturedDataSaver.save(data: cameraCaptureData, to: filePath, withPrefix: prefix)
        
        
        
//        let colorImage = cameraCaptureData.colorImage!
//        let depthImage = cameraCaptureData.depthImage!
//        // Combine color and depth images
//        UIGraphicsBeginImageContext(colorImage.size)
//        colorImage.draw(in: CGRect(origin: .zero, size: colorImage.size))
//        depthImage.draw(in: CGRect(origin: .zero, size: colorImage.size), blendMode: .overlay, alpha: 0.8)
//        let combinedImage = UIGraphicsGetImageFromCurrentImageContext()
//        UIGraphicsEndImageContext()
//        
//        // Display combined image
//        imageView.image = combinedImage?.withOrientation(.right)
    }

    private func createCameraCapturedData(pixelBuffer: CVPixelBuffer,
                                          depthData: AVDepthData,
                                          motionMetadata: MotionMetadata) -> CameraCapturedData {
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let colorImage = UIImage(ciImage: ciImage)
        
        // Convert depth data and lock buffer
        let depthMap = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32).depthDataMap
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) } // Ensure unlock on exit
        
        // Get depth dimensions and pointer
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let depthPointer = CVPixelBufferGetBaseAddress(depthMap)!.assumingMemoryBound(to: Float32.self)
        
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
        let provider = CGDataProvider(data: Data(depthPixels) as CFData)!
        let cgDepthImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width, space: colorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        
        
        let cameraCalibrationData = depthData.cameraCalibrationData!
        
        let data = CameraCapturedData(colorImage: colorImage.withOrientation(.right),
                                      depthImage: UIImage(cgImage: cgDepthImage),
                                      motionMetadta: motionMetadata,
                                      minDepth: minDepth,
                                      maxDepth: maxDepth,
                                      cameraIntrinsics: cameraCalibrationData.intrinsicMatrix,
                                      cameraReferenceDimensions: cameraCalibrationData.intrinsicMatrixReferenceDimensions)
        return data
    }
    
    func getICloudDirectory() -> URL? {
        // Retrieve the iCloud container
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            let appDirectory = iCloudURL.appendingPathComponent("Documents/SavedCaptures")
            
            // Create the directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: appDirectory.path) {
                do {
                    try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
                } catch {
                    print("Failed to create iCloud directory: \(error)")
                    return nil
                }
            }
            return appDirectory
        } else {
            print("iCloud is not available.")
            return nil
        }
    }
    
    private func getObjectFolderPath(folderName: String) -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = documentsDirectory.appendingPathComponent(folderName)
        
        // Create folder if it doesn't exist
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            } catch {
                print("Failed to create object folder: \(error)")
            }
        }
        
        return folderURL
    }
    
    
    // Dismiss the keyboard when tapping outside the text field
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // UITextFieldDelegate method to dismiss keyboard on return key
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    
    @objc func shareFiles() {
        // Get object name from text field or use default
        let objectName = objectNameTextField.text?.isEmpty == true ? "DefaultObject" : objectNameTextField.text!
        let folderPath = getObjectFolderPath(folderName: objectName)
        
        do {
            // Retrieve all file URLs in the object folder
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folderPath, includingPropertiesForKeys: nil)
            
            // Initialize activity view controller with files
            let activityVC = UIActivityViewController(activityItems: fileURLs, applicationActivities: nil)
            activityVC.popoverPresentationController?.sourceView = self.view // for iPad compatibility
            present(activityVC, animated: true, completion: nil)
            
        } catch {
            print("Failed to retrieve files for sharing: \(error)")
        }
    }
}
