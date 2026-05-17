import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var emulator = EmulatorProcess()
    @StateObject private var capture = FrameCapture()
    @StateObject private var inputManager = ADBInputManager()
    
    // Default Android emulator resolution
    let androidWidth: CGFloat = 1080
    let androidHeight: CGFloat = 1920
    
    var body: some View {
        ZStack {
            // Arca Identity: Obsidian Background
            Color(red: 15/255, green: 15/255, blue: 15/255)
                .edgesIgnoringSafeArea(.all)
            
            if let frame = capture.currentFrame {
                GeometryReader { geo in
                    Image(nsImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                        // Capture clicks using DragGesture
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    handleInput(start: value.startLocation, end: value.location, in: geo.size)
                                }
                        )
                }
            } else {
                VStack(spacing: 24) {
                    ProgressView()
                        // Arca Identity: Arc Blue tint
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 91/255, green: 156/255, blue: 246/255)))
                        .scaleEffect(1.2)
                    
                    Text("arca is bridging your app...")
                        // Arca Identity: System Font (SF Pro)
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundColor(Color(red: 245/255, green: 245/255, blue: 243/255))
                }
            }
        }
        .onAppear {
            emulator.start()
            
            let config = loadConfig()
            // Set the native macOS window title
            if let window = NSApplication.shared.windows.first {
                window.title = config.appName
            }
            
            // Give the emulator 3.5 seconds to fully boot before we start capturing frames
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                capture.startCapturing()
                launchApp(packageName: config.packageName) // Launches the dynamic app!
            }
        }
        .onDisappear {
            capture.stopCapturing()
            emulator.stop()
            inputManager.stop()
        }
        .frame(minWidth: 360, minHeight: 640)
    }
    
    private func handleInput(start: CGPoint, end: CGPoint, in size: CGSize) {
        // Calculate the aspect ratio of the image and the view
        let imageAspect = androidWidth / androidHeight
        let viewAspect = size.width / size.height
        
        var renderWidth: CGFloat = 0
        var renderHeight: CGFloat = 0
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0
        
        if viewAspect > imageAspect {
            renderHeight = size.height
            renderWidth = renderHeight * imageAspect
            offsetX = (size.width - renderWidth) / 2
        } else {
            renderWidth = size.width
            renderHeight = renderWidth / imageAspect
            offsetY = (size.height - renderHeight) / 2
        }
        
        // Clamp points to be within the Android screen bounds
        let startX = max(offsetX, min(start.x, offsetX + renderWidth))
        let startY = max(offsetY, min(start.y, offsetY + renderHeight))
        let endX = max(offsetX, min(end.x, offsetX + renderWidth))
        let endY = max(offsetY, min(end.y, offsetY + renderHeight))
        
        let normStartX = (startX - offsetX) / renderWidth
        let normStartY = (startY - offsetY) / renderHeight
        let normEndX = (endX - offsetX) / renderWidth
        let normEndY = (endY - offsetY) / renderHeight
        
        let aStartX = Int(normStartX * androidWidth)
        let aStartY = Int(normStartY * androidHeight)
        let aEndX = Int(normEndX * androidWidth)
        let aEndY = Int(normEndY * androidHeight)
        
        let distance = hypot(Double(aEndX - aStartX), Double(aEndY - aStartY))
        
        DispatchQueue.global(qos: .userInteractive).async {
            if distance < 20 { // Tap
                inputManager.tap(x: aEndX, y: aEndY)
            } else { // Swipe
                inputManager.swipe(startX: aStartX, startY: aStartY, endX: aEndX, endY: aEndY, duration: 400)
            }
        }
    }
    
    private func launchApp(packageName: String) {
        DispatchQueue.global(qos: .background).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/share/android-commandlinetools/platform-tools/adb")
            process.arguments = ["shell", "monkey", "-p", packageName, "-c", "android.intent.category.LAUNCHER", "1"]
            try? process.run()
        }
    }
    
    private func loadConfig() -> (appName: String, packageName: String) {
        // Read the target package from the app bundle resources if it exists
        if let configPath = Bundle.main.path(forResource: "arca_config", ofType: "txt"),
           let configString = try? String(contentsOfFile: configPath, encoding: .utf8) {
            let lines = configString.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if lines.count >= 2 {
                return (lines[0].trimmingCharacters(in: .whitespaces), lines[1].trimmingCharacters(in: .whitespaces))
            } else if lines.count == 1 {
                return ("Arca App", lines[0].trimmingCharacters(in: .whitespaces))
            }
        }
        // Fallback for when we run it directly from Xcode for testing
        return ("Arca Debug", "com.vagujhelyigergely.calculatorm3") 
    }
}

// MARK: - Fast Input Manager
class ADBInputManager: ObservableObject {
    @Published var isReady = false
    private var process: Process?
    private var pipe: Pipe?
    
    init() {
        start()
    }
    
    func start() {
        DispatchQueue.global(qos: .background).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/share/android-commandlinetools/platform-tools/adb")
            process.arguments = ["shell"]
            let pipe = Pipe()
            process.standardInput = pipe
            try? process.run()
            
            self.process = process
            self.pipe = pipe
        }
    }
    
    func stop() {
        process?.terminate()
    }
    
    func tap(x: Int, y: Int) {
        let command = "input tap \(x) \(y)\n"
        if let data = command.data(using: .utf8) {
            try? pipe?.fileHandleForWriting.write(contentsOf: data)
        }
    }
    
    func swipe(startX: Int, startY: Int, endX: Int, endY: Int, duration: Int) {
        let command = "input swipe \(startX) \(startY) \(endX) \(endY) \(duration)\n"
        if let data = command.data(using: .utf8) {
            try? pipe?.fileHandleForWriting.write(contentsOf: data)
        }
    }
}
