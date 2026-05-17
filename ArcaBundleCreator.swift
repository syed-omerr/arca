import SwiftUI
import UniformTypeIdentifiers
import AppKit

@main
struct ArcaBundleCreatorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 500, height: 400)
                .background(Color(red: 15/255, green: 15/255, blue: 15/255))
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct ContentView: View {
    @State private var isHovering = false
    @State private var isProcessing = false
    @State private var progressMessage = ""
    @State private var success = false
    @State private var hasError = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("arca")
                .font(.custom("Georgia-Bold", size: 36))
                .foregroundColor(.white)
            
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isHovering ? Color(hex: "5B9CF6") : Color(hex: "333333"), style: StrokeStyle(lineWidth: 3, dash: [10]))
                    .background(Color.white.opacity(isHovering ? 0.05 : 0.02))
                    .cornerRadius(20)
                
                VStack(spacing: 16) {
                    if success {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.green)
                            .transition(.scale)
                    } else {
                        Image(systemName: "apps.ipad.landscape")
                            .font(.system(size: 56))
                            .foregroundColor(Color(hex: "5B9CF6"))
                    }
                    
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "5B9CF6")))
                            .scaleEffect(1.2)
                            .padding(.bottom, 4)
                        Text(progressMessage)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .padding(.horizontal, 20)
                    } else if success {
                        Text("Mac App Created Successfully!")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                        Text("Check your Desktop")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    } else if hasError {
                        Text("Error")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.red)
                        Text(progressMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    } else {
                        Text("Drop an .apk here")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        Text("It will instantly wrap into a native Mac app")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                
                // Native macOS Drop Zone
                DropView(isHovering: $isHovering) { url in
                    handleNativeDrop(url: url)
                }
            }
            .frame(width: 400, height: 250)
        }
        .padding()
    }
    
    private func handleNativeDrop(url: URL) {
        guard !isProcessing else { return }
        success = false
        hasError = false
        
        guard url.pathExtension.lowercased() == "apk" else {
            DispatchQueue.main.async {
                self.hasError = true
                self.progressMessage = "Invalid file type. Expected .apk"
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.progressMessage = "Analyzing \(url.lastPathComponent)..."
            self.runWrapScript(apkPath: url.path)
        }
    }
    
    private func runWrapScript(apkPath: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: apkPath)
            let process = Process()
            
            // To bypass macOS Sandbox/TCC blocking bash from reading the Downloads folder,
            // we copy the dropped APK into the system Temp directory first.
            let tempAPK = NSTemporaryDirectory() + url.lastPathComponent
            try? FileManager.default.removeItem(atPath: tempAPK)
            do {
                try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: tempAPK))
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.hasError = true
                    self.progressMessage = "Failed to access dropped file: \(error.localizedDescription)"
                }
                return
            }
            
            // Execute the script embedded directly inside the App Bundle
            guard let scriptPath = Bundle.main.path(forResource: "wrap_apk", ofType: "sh") else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.hasError = true
                    self.progressMessage = "Internal Error: Missing wrap_apk.sh"
                }
                return
            }
            
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath, tempAPK]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            let outHandle = pipe.fileHandleForReading
            outHandle.readabilityHandler = { pipe in
                if let line = String(data: pipe.availableData, encoding: .utf8), !line.isEmpty {
                    let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleanLine.isEmpty || cleanLine.starts(with: "=") { return }
                    DispatchQueue.main.async {
                        self.progressMessage = String(cleanLine.prefix(40))
                    }
                }
            }
            
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.hasError = true
                    self.progressMessage = "Error launching script: \(error.localizedDescription)"
                }
                return
            }
            
            DispatchQueue.main.async {
                self.isProcessing = false
                if process.terminationStatus == 0 {
                    withAnimation {
                        self.success = true
                    }
                    NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/Desktop"))
                } else {
                    self.hasError = true
                    // If it failed and we didn't get any output, show a generic message
                    if self.progressMessage.isEmpty || self.progressMessage.contains("Analyzing") {
                        self.progressMessage = "Script failed (exit code \(process.terminationStatus))."
                    }
                }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Native AppKit Drop Zone
struct DropView: NSViewRepresentable {
    @Binding var isHovering: Bool
    var onDrop: (URL) -> Void
    
    func makeNSView(context: Context) -> DroppableView {
        let view = DroppableView()
        view.onHover = { hover in self.isHovering = hover }
        view.onDrop = { url in self.onDrop(url) }
        return view
    }
    
    func updateNSView(_ nsView: DroppableView, context: Context) {}
}

class DroppableView: NSView {
    var onHover: ((Bool) -> Void)?
    var onDrop: ((URL) -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            NSPasteboard.PasteboardType("public.file-url")
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onHover?(true)
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        onHover?(false)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onHover?(false)
        let pasteboard = sender.draggingPasteboard
        
        // Method 1: NSURL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let url = urls.first {
            onDrop?(url)
            return true
        }
        
        // Method 2: NSFilenames
        if let files = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String], let path = files.first {
            onDrop?(URL(fileURLWithPath: path))
            return true
        }
        
        // Method 3: Raw string
        if let string = pasteboard.string(forType: .string), string.hasPrefix("file://"), let url = URL(string: string) {
            onDrop?(url)
            return true
        }
        
        return false
    }
}
