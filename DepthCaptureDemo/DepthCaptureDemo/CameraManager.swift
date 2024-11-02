import UIKit

class CameraCapturedData {
    // Properties to store images and metadata for each capture
    struct FrameData {
        let colorImage: UIImage
        let depthImage: UIImage
        let intrinsicMatrix: [[Float]]
        let minDepth: Float
        let maxDepth: Float
    }
    
    private var frames: [FrameData] = []
    
    // Methods to add new frames
    func addFrame(colorImage: UIImage, depthImage: UIImage, intrinsicMatrix: [[Float]], minDepth: Float, maxDepth: Float) {
        let frameData = FrameData(
            colorImage: colorImage,
            depthImage: depthImage,
            intrinsicMatrix: intrinsicMatrix,
            minDepth: minDepth,
            maxDepth: maxDepth
        )
        frames.append(frameData)
    }
    
    // Accessors
    func getFrames() -> [FrameData] {
        return frames
    }
}

