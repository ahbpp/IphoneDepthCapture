import UIKit
import simd

class CameraCapturedData {
    // Store color and depth images, along with camera metadata
    var colorImage: UIImage?
    var depthImage: UIImage?
    var minDepth: Float
    var maxDepth: Float
    var cameraIntrinsics: matrix_float3x3
    var cameraReferenceDimensions: CGSize
    
    init(colorImage: UIImage? = nil,
         depthImage: UIImage? = nil,
         minDepth: Float,
         maxDepth: Float,
         cameraIntrinsics: matrix_float3x3 = matrix_float3x3(),
         cameraReferenceDimensions: CGSize = .zero) {
        
        self.colorImage = colorImage
        self.depthImage = depthImage
        self.minDepth = minDepth
        self.maxDepth = maxDepth
        self.cameraIntrinsics = cameraIntrinsics
        self.cameraReferenceDimensions = cameraReferenceDimensions
    }
    
    // Add method to update properties
    func update(colorImage: UIImage,
                depthImage: UIImage,
                minDepth: Float,
                maxDepth: Float,
                cameraIntrinsics: matrix_float3x3,
                cameraReferenceDimensions: CGSize) {
        self.colorImage = colorImage
        self.depthImage = depthImage
        self.minDepth = minDepth
        self.maxDepth = maxDepth
        self.cameraIntrinsics = cameraIntrinsics
        self.cameraReferenceDimensions = cameraReferenceDimensions
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
            
            // Save depth image
            if let depthImage = data.depthImage {
                let depthImageURL = folderPath.appendingPathComponent("\(prefix)_depthImage.png")
                saveImage(depthImage, to: depthImageURL, asPNG: true)
            }
            
            // Save metadata
            let metadataURL = folderPath.appendingPathComponent("\(prefix)_metadata.json")
            let metadata = createMetadataDictionary(data: data)
            let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
            try jsonData.write(to: metadataURL)
            
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
            ]
        ]
    }
}
