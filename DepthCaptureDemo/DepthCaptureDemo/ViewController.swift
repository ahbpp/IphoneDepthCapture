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
    var objectNameTextField: UITextField! // New text field for object name

    // Capture session and outputs
    var captureSession: AVCaptureSession!
    var depthDataOutput: AVCaptureDepthDataOutput!
    var photoOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    let cameraCapturedDataSaver = CameraCapturedDataSaver()
    
    // Variables for managing capture
       var captureCounter = 0 // Counter for number of images taken for the object


    override func viewDidLoad() {
        super.viewDidLoad()

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
        // Set up object name text field
         objectNameTextField = UITextField(frame: CGRect(x: 20, y: 50, width: 200, height: 40))
         objectNameTextField.placeholder = "Enter Object Name"
         objectNameTextField.borderStyle = .roundedRect
         view.addSubview(objectNameTextField)
        
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
        guard let pixelBuffer = photo.pixelBuffer, let depthData = photo.depthData, error == nil else {
            print("Error capturing photo: \(String(describing: error))")
            return
        }
        
        captureCounter += 1
        
        let cameraCaptureData = createCameraCapturedData(pixelBuffer: pixelBuffer, depthData: depthData)
        
        // Define folder path and prefix
        let objectName = objectNameTextField.text?.isEmpty == true ? "DefaultObject" : objectNameTextField.text!
        let filePath = getObjectFolderPath(folderName: objectName)
        let prefix = "fram_\(captureCounter)"
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

    private func createCameraCapturedData(pixelBuffer: CVPixelBuffer, depthData: AVDepthData) -> CameraCapturedData {
        
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
                                      depthImage: UIImage(cgImage: cgDepthImage).withOrientation(.right),
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
}
