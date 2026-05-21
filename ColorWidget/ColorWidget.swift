import WidgetKit
import SwiftUI

struct ColorEntry: TimelineEntry {
    let date: Date
    let hex: String
    let color: Color
}

struct ColorProvider: TimelineProvider {
    func placeholder(in context: Context) -> ColorEntry {
        ColorEntry(date: .now, hex: "#3B82F6", color: .blue)
    }
    func getSnapshot(in context: Context, completion: @escaping (ColorEntry) -> Void) {
        completion(makeEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ColorEntry>) -> Void) {
        completion(Timeline(entries: [makeEntry()], policy: .never))
    }
    func makeEntry() -> ColorEntry {
        let defaults = UserDefaults(suiteName: "group.com.jessica.ColorPicker")
        let hex = defaults?.string(forKey: "lastColor") ?? "#3B82F6"
        return ColorEntry(date: .now, hex: hex, color: colorFromHex(hex))
    }
    func colorFromHex(_ hex: String) -> Color {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return .blue }
        return Color(red: Double((val>>16)&0xFF)/255,
                     green: Double((val>>8)&0xFF)/255,
                     blue: Double(val&0xFF)/255)
    }
}

struct ColorWidgetEntryView: View {
    let entry: ColorEntry
    var body: some View {
        Circle()
            .fill(Color(red: 0.21, green: 0.24, blue: 0.28))
            .overlay(
                Image(systemName: "eyedropper.full")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Color(red: 0.97, green: 0.95, blue: 0.92))
            )
            .containerBackground(.clear, for: .widget)
    }
}

struct ColorWidget: Widget {
    let kind: String = "ColorWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ColorProvider()) { entry in
            ColorWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Color Picker")
        .description("Tap to open the color detector")
        .supportedFamilies([.accessoryCircular])
        .contentMarginsDisabled()
    }
}
