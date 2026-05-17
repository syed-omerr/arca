import Foundation
import AppKit
import Combine

class FrameCapture: ObservableObject {
    @Published var currentFrame: NSImage?
    private var timer: Timer?
    private var isCapturingFrame = false
    
    func startCapturing() {
        // Poll for frames at 10fps (0.1s interval). We use a flag to prevent overlapping captures.
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.captureFrame()
        }
    }
    
    func stopCapturing() {
        timer?.invalidate()
        timer = nil
    }
    
    private func captureFrame() {
        guard !isCapturingFrame else { return }
        isCapturingFrame = true
        
        DispatchQueue.global(qos: .userInteractive).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/share/android-commandlinetools/platform-tools/adb")
            process.arguments = ["exec-out", "screencap", "-p"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                
                if let image = NSImage(data: data) {
                    DispatchQueue.main.async {
                        self.currentFrame = image
                        self.isCapturingFrame = false
                    }
                } else {
                    self.isCapturingFrame = false
                }
            } catch {
                print("Capture error: \(error)")
                self.isCapturingFrame = false
            }
        }
    }
}
