import AVFoundation
import Combine
import SwiftUI

class CameraModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    // 即時顏色（只用來給相機內部讀取，不顯示）
    private var liveColor: (r: Int, g: Int, b: Int) = (128, 128, 128)

    // 鎖定後的顏色（顯示在 UI 上）
    @Published var detectedColor: Color = .gray
    @Published var hexColor: String = "#888888"
    @Published var rgbString: String = "128, 128, 128"
    @Published var hslString: String = "0° 0% 50%"
    @Published var textColor: Color = .white
    @Published var isLocked: Bool = false

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "camera.queue")

    func start() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:
                                 kCVPixelFormatType_32BGRA]
        session.addOutput(output)
        DispatchQueue.global().async { self.session.startRunning() }
    }

    func stop() { session.stopRunning() }

    // 點擊時呼叫，鎖定當下顏色
    func captureCurrentColor() {
        let r = liveColor.r
        let g = liveColor.g
        let b = liveColor.b
        let hex = String(format: "#%02X%02X%02X", r, g, b)
        let (h, s, l) = rgbToHsl(r: r, g: g, b: b)
        let luminance = 0.299*Double(r) + 0.587*Double(g) + 0.114*Double(b)

        DispatchQueue.main.async {
            self.detectedColor = Color(red: Double(r)/255,
                                       green: Double(g)/255,
                                       blue: Double(b)/255)
            self.hexColor = hex
            self.rgbString = "\(r), \(g), \(b)"
            self.hslString = "\(h)° \(s)% \(l)%"
            self.textColor = luminance > 128 ? .black : .white
            self.isLocked = true

            // 震動回饋
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput buffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return }
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

        let w = CVPixelBufferGetWidth(imageBuffer)
        let h = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        guard let base = CVPixelBufferGetBaseAddress(imageBuffer) else { return }

        let cx = w / 2, cy = h / 2, size = 2
        var rSum = 0, gSum = 0, bSum = 0, count = 0
        for dy in -size...size {
            for dx in -size...size {
                let px = cx + dx, py = cy + dy
                guard px >= 0, py >= 0, px < w, py < h else { continue }
                let ptr = base.advanced(by: py * bytesPerRow + px * 4)
                    .assumingMemoryBound(to: UInt8.self)
                bSum += Int(ptr[0]); gSum += Int(ptr[1]); rSum += Int(ptr[2])
                count += 1
            }
        }
        guard count > 0 else { return }

        // 只更新 liveColor，不更新 UI
        liveColor = (rSum/count, gSum/count, bSum/count)
    }

    func rgbToHsl(r: Int, g: Int, b: Int) -> (Int, Int, Int) {
        let rf = Double(r)/255, gf = Double(g)/255, bf = Double(b)/255
        let mx = max(rf,gf,bf), mn = min(rf,gf,bf)
        let l = (mx+mn)/2
        if mx == mn { return (0, 0, Int(l*100)) }
        let d = mx - mn
        let s = l > 0.5 ? d/(2-mx-mn) : d/(mx+mn)
        var h: Double
        switch mx {
        case rf: h = (gf-bf)/d + (gf < bf ? 6 : 0)
        case gf: h = (bf-rf)/d + 2
        default: h = (rf-gf)/d + 4
        }
        return (Int(h/6*360), Int(s*100), Int(l*100))
    }
}
