import Foundation
import Combine

class EmulatorProcess: ObservableObject {
    private var process: Process?
    @Published var isRunning = false
    
    func start() {
        guard !isRunning else { return }
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: "/usr/local/share/android-commandlinetools/emulator/emulator")
        process?.arguments = [
            "-avd", "applet_test", "-accel", "auto", "-gpu", "host", "-no-window", "-no-audio", "-memory", "512", "-snapshot", "ready"
        ]
        
        do {
            try process?.run()
            DispatchQueue.main.async {
                self.isRunning = true
            }
        } catch {
            print("Failed to start emulator: \(error)")
        }
    }
    
    func stop() {
        guard isRunning else { return }
        
        // Cleanly shut down the emulator via adb
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/usr/local/share/android-commandlinetools/platform-tools/adb")
        killProcess.arguments = ["emu", "kill"]
        
        do {
            try killProcess.run()
            killProcess.waitUntilExit()
        } catch {
            print("Failed to kill emulator cleanly.")
        }
        
        process?.terminate()
        DispatchQueue.main.async {
            self.isRunning = false
        }
    }
}
