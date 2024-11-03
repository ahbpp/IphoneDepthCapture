import UIKit
import CoreMotion
import simd

class CameraCapturedData {
    // Store color and depth images, along with camera metadata
    var colorImage: UIImage?
    var depthImage: UIImage?
    var motionMetadta: MotionMetadata?
    var minDepth: Float
    var maxDepth: Float
    var cameraIntrinsics: matrix_float3x3
    var cameraReferenceDimensions: CGSize
    
    init(colorImage: UIImage? = nil,
         depthImage: UIImage? = nil,
         motionMetadta: MotionMetadata? = nil,
         minDepth: Float,
         maxDepth: Float,
         cameraIntrinsics: matrix_float3x3 = matrix_float3x3(),
         cameraReferenceDimensions: CGSize = .zero) {
        
        self.colorImage = colorImage
        self.depthImage = depthImage
        self.motionMetadta = motionMetadta
        self.minDepth = minDepth
        self.maxDepth = maxDepth
        self.cameraIntrinsics = cameraIntrinsics
        self.cameraReferenceDimensions = cameraReferenceDimensions
    }
    
    // Add method to update properties
    func update(colorImage: UIImage,
                depthImage: UIImage,
                motionMetadta: MotionMetadata,
                minDepth: Float,
                maxDepth: Float,
                cameraIntrinsics: matrix_float3x3,
                cameraReferenceDimensions: CGSize) {
        self.colorImage = colorImage
        self.depthImage = depthImage
        self.motionMetadta = motionMetadta
        self.minDepth = minDepth
        self.maxDepth = maxDepth
        self.cameraIntrinsics = cameraIntrinsics
        self.cameraReferenceDimensions = cameraReferenceDimensions
    }
}

class MotionMetadata {
    // Properties to hold orientation and acceleration data
    private var roll: Double
    private var pitch: Double
    private var yaw: Double
    private var accelerationX: Double
    private var accelerationY: Double
    private var accelerationZ: Double
    
    // Initializer to set orientation and acceleration data
    init(orientationData: (roll: Double, pitch: Double, yaw: Double)?, accelerationData: CMAcceleration?) {
        // Assign orientation data or default to 0 if nil
        self.roll = orientationData?.roll ?? 0.0
        self.pitch = orientationData?.pitch ?? 0.0
        self.yaw = orientationData?.yaw ?? 0.0
        
        // Assign acceleration data or default to 0 if nil
        self.accelerationX = accelerationData?.x ?? 0.0
        self.accelerationY = accelerationData?.y ?? 0.0
        self.accelerationZ = accelerationData?.z ?? 0.0
    }
    
    // Method to get metadata as a dictionary
    func toDictionary() -> [String: Any] {
        return [
            "orientation": [
                "roll": roll,
                "pitch": pitch,
                "yaw": yaw
            ],
            "acceleration": [
                "x": accelerationX,
                "y": accelerationY,
                "z": accelerationZ
            ]
        ]
    }
}



class CameraCapturedDataSaver {
    // Save method for CameraCapturedData
    func save(data: CameraCapturedData, to folderPath: URL, withPrefix prefix: String) {
        do {
            // Create the folder if it doesn't exist
            try FileManager.default.createDirectory(at: folderPath, withIntermediateDirectories: true)
            
            // Save color image
            if let colorImage = data.colorImage {
                let colorImageURL = folderPath.appendingPathComponent("\(prefix)_colorImage.jpg")
                saveImage(colorImage, to: colorImageURL, asPNG: false)
            }
            
            
            // Save metadata
            let metadataURL = folderPath.appendingPathComponent("\(prefix)_metadata.json")
            let metadata = createMetadataDictionary(data: data)
            let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
            try jsonData.write(to: metadataURL)
            
            // Save depth image
            if let depthImage = data.depthImage {
                let depthImageURL = folderPath.appendingPathComponent("\(prefix)_depthImage.png")
                saveImageWithMetadata(depthImage, metadata: metadata, to: depthImageURL)
            }
            
            print("Saved all data to \(folderPath)")
        } catch {
            print("Failed to save data: \(error)")
        }
    }
    
    // Helper to save an image in the specified format
    private func saveImage(_ image: UIImage, to url: URL, asPNG: Bool) {
        guard let data = asPNG ? image.pngData() : image.jpegData(compressionQuality: 1.0) else {
            print("Failed to convert image to data.")
            return
        }
        do {
            try data.write(to: url)
            print("Saved image at \(url.path)")
        } catch {
            print("Failed to save image: \(error)")
        }
    }
    
    
    // Save PNG image with embedded JSON metadata
    private func saveImageWithMetadata(_ image: UIImage, metadata: [String: Any], to url: URL) {
        guard let pngData = image.pngData() else { return }

        // Convert metadata dictionary to JSON string
        guard let jsonData = try? JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Failed to convert metadata to JSON string.")
            return
        }
        
        // Create CGImageSource and CGImageDestination to manipulate PNG data
        guard let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let imageType = CGImageSourceGetType(source),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, imageType, 1, nil) else {
            print("Failed to create image source or destination.")
            return
        }
        
        // Create metadata dictionary with JSON string embedded
        let metadataDict: [String: Any] = [
            kCGImagePropertyPNGDictionary as String: [
                kCGImagePropertyPNGDescription as String: jsonString // Embed JSON in PNG "Description" field
            ]
        ]
        
        // Add image with metadata to destination
        CGImageDestinationAddImageFromSource(destination, source, 0, metadataDict as CFDictionary)
        
        // Finalize and save
        if CGImageDestinationFinalize(destination) {
            print("Image with metadata saved to \(url.path)")
        } else {
            print("Failed to finalize image with metadata.")
        }
    }
    
    // Helper to create metadata dictionary
    private func createMetadataDictionary(data: CameraCapturedData) -> [String: Any] {
        return [
            "minDepth": data.minDepth,
            "maxDepth": data.maxDepth,
            "cameraIntrinsics": [
                [data.cameraIntrinsics[0, 0], data.cameraIntrinsics[0, 1], data.cameraIntrinsics[0, 2]],
                [data.cameraIntrinsics[1, 0], data.cameraIntrinsics[1, 1], data.cameraIntrinsics[1, 2]],
                [data.cameraIntrinsics[2, 0], data.cameraIntrinsics[2, 1], data.cameraIntrinsics[2, 2]]
            ],
            "cameraReferenceDimensions": [
                "width": data.cameraReferenceDimensions.width,
                "height": data.cameraReferenceDimensions.height
            ],
            "motionMetadata": data.motionMetadta?.toDictionary() ?? []
        ]
    }
}
