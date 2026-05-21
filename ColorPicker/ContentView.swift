import AVFoundation
import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject private var camera = CameraModel()
    @State private var savedColors: [SavedColor] = []
    @State private var showCopied = false
    @State private var copiedColorId: UUID? = nil
    @State private var isEditing = false

    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
                .ignoresSafeArea()
                // 點擊畫面任意位置取色
                .onTapGesture {
                    camera.captureCurrentColor()
                }

            // 準心：外框顏色跟著鎖定顏色變
            ZStack {
                Circle()
                    .strokeBorder(
                        camera.isLocked ? camera.detectedColor : Color.white,
                        lineWidth: 2
                    )
                    .frame(width: 60, height: 60)
                    .animation(.easeInOut(duration: 0.2), value: camera.isLocked)

                Circle()
                    .fill(camera.isLocked ? camera.detectedColor : Color.white.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))
                    .animation(.easeInOut(duration: 0.2), value: camera.detectedColor)
            }

            // 點空白處取消編輯
            if isEditing {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring()) { isEditing = false }
                    }
            }

            VStack {
                Spacer()
                VStack(spacing: 12) {
                    // 顏色預覽
                    RoundedRectangle(cornerRadius: 12)
                        .fill(camera.detectedColor)
                        .frame(height: 60)
                        .overlay(
                            Text(camera.hexColor)
                                .font(.system(.title2, design: .monospaced))
                                .fontWeight(.medium)
                                .foregroundColor(camera.textColor)
                        )

                    // HEX / RGB / HSL + 鎖頭
                    HStack(spacing: 8) {
                        InfoPill(label: "HEX", value: camera.hexColor)
                        InfoPill(label: "RGB", value: camera.rgbString)
                        InfoPill(label: "HSL", value: camera.hslString)

                        // 鎖頭
                        if camera.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(6)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(8)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.spring(), value: camera.isLocked)

                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = camera.hexColor
                            showCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now()+1.5) {
                                showCopied = false
                            }
                        } label: {
                            Label(showCopied ? "Copied!" : "Copy HEX",
                                  systemImage: showCopied ? "checkmark" : "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button { saveColor() } label: {
                            Label("Save", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }

                    if !savedColors.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(savedColors) { c in
                                    ColorCircleView(
                                        savedColor: c,
                                        isEditing: isEditing,
                                        isCopied: copiedColorId == c.id,
                                        onTap: {
                                            guard !isEditing else { return }
                                            UIPasteboard.general.string = c.hex
                                            withAnimation(.spring()) { copiedColorId = c.id }
                                            DispatchQueue.main.asyncAfter(deadline: .now()+2) {
                                                withAnimation(.spring()) { copiedColorId = nil }
                                            }
                                        },
                                        onLongPress: {
                                            withAnimation(.spring()) { isEditing = true }
                                        },
                                        onDelete: {
                                            withAnimation(.spring()) {
                                                savedColors.removeAll { $0.id == c.id }
                                                if savedColors.isEmpty { isEditing = false }
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                if isEditing {
                                    withAnimation(.spring()) { isEditing = false }
                                }
                            }
                        )
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(16)
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    func saveColor() {
        let c = SavedColor(hex: camera.hexColor, color: camera.detectedColor)
        savedColors.insert(c, at: 0)
        if savedColors.count > 12 { savedColors.removeLast() }
        let defaults = UserDefaults(suiteName: "group.com.jessica.ColorPicker")
        defaults?.set(camera.hexColor, forKey: "lastColor")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct ColorCircleView: View {
    let savedColor: SavedColor
    let isEditing: Bool
    let isCopied: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onDelete: () -> Void

    private let circleSize: CGFloat = 32
    private let bubbleAreaHeight: CGFloat = 40

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                Color.clear.frame(height: bubbleAreaHeight)
                if isCopied {
                    VStack(spacing: 0) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                            Text(savedColor.hex)
                                .font(.system(size: 11, design: .monospaced))
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(.regularMaterial)
                                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        )
                        Triangle()
                            .fill(.regularMaterial)
                            .frame(width: 10, height: 5)
                    }
                    .fixedSize()
                    .allowsHitTesting(false)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.85, anchor: .bottom)),
                        removal: .opacity
                    ))
                    .zIndex(100)
                }
            }

            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(savedColor.color)
                    .frame(width: circleSize, height: circleSize)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
                    .onTapGesture { onTap() }
                    .onLongPressGesture { onLongPress() }

                if isEditing {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5), in: Circle())
                    }
                    .offset(x: 10, y: -10)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(99)
                }
            }
            .frame(width: circleSize + 12, height: circleSize + 12)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct SavedColor: Identifiable {
    let id = UUID()
    let hex: String
    let color: Color
}

struct InfoPill: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.15))
        .cornerRadius(8)
    }
}

struct CameraPreview: UIViewRepresentable {
    let camera: CameraModel
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = camera.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

#Preview {
    ContentView()
}
