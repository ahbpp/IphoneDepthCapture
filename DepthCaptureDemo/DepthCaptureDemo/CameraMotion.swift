//
//  CameraMotion.swift
//  DepthCaptureDemo
//
//  Created by Aleksei Karpov on 2024-11-02.
//

import CoreMotion


class CameraMotion {
    private let motionManager = CMMotionManager()
    private var initialAttitude: CMAttitude?
    
    // Variables to store acceleration data
    private var lastAcceleration: CMAcceleration?

    func startTracking() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard error == nil, let motion = motion else {
                    print("Motion update error: \(String(describing: error))")
                    return
                }
                
                // Set initial attitude as the reference
                if self?.initialAttitude == nil {
                    self?.initialAttitude = motion.attitude
                }
                
                // Save acceleration data for relative movement tracking
                self?.lastAcceleration = motion.userAcceleration
            }
        }
    }

    func getRelativeOrientation() -> (roll: Double, pitch: Double, yaw: Double)? {
        guard let currentAttitude = motionManager.deviceMotion?.attitude, let initialAttitude = initialAttitude else {
            return nil
        }
        
        currentAttitude.multiply(byInverseOf: initialAttitude)
        return (roll: currentAttitude.roll, pitch: currentAttitude.pitch, yaw: currentAttitude.yaw)
    }
    
    func getRelativeAcceleration() -> CMAcceleration? {
        return lastAcceleration
    }

    func stopTracking() {
        motionManager.stopDeviceMotionUpdates()
    }
}
