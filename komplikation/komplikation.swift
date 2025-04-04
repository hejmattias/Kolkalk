import WidgetKit
import SwiftUI

// MARK: - ExistingComplication

struct ExistingComplication: Widget {
    let kind: String = "komplikation"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            KomplikationEntryView(entry: entry)
        }
        .configurationDisplayName("Kolhydratkomplikation")
        .description("Visar totala gram kolhydrater på tallriken.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> KomplikationEntry {
        KomplikationEntry(date: Date(), totalCarbs: 0.0)
    }

    func getSnapshot(in context: Context, completion: @escaping (KomplikationEntry) -> Void) {
        let totalCarbs = fetchTotalCarbs()
        let entry = KomplikationEntry(date: Date(), totalCarbs: totalCarbs)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KomplikationEntry>) -> Void) {
        let totalCarbs = fetchTotalCarbs()
        let entry = KomplikationEntry(date: Date(), totalCarbs: totalCarbs)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }

    private func fetchTotalCarbs() -> Double {
        let appGroupID = "group.mg.kolkalk" // Ersätt med ditt faktiska App Group ID

        if let userDefaults = UserDefaults(suiteName: appGroupID) {
            let totalCarbs = userDefaults.double(forKey: "totalCarbs")
            return totalCarbs
        } else {
            print("Kunde inte initialisera UserDefaults med App Group ID: \(appGroupID) i komplikationen")
        }
        return 0.0
    }
}

struct KomplikationEntry: TimelineEntry {
    let date: Date
    let totalCarbs: Double
}

struct KomplikationEntryView: View {
    let entry: KomplikationEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Text(String(format: "%.1f", entry.totalCarbs))
                .widgetURL(URL(string: "kolkalk://FoodPlate"))
                .widgetLabel {
                    Text("på tallriken")
                }
                .containerBackground(.fill, for: .widget)
        case .accessoryCorner:
            Text(String(format: "%.1f gk", entry.totalCarbs))
                .widgetURL(URL(string: "kolkalk://FoodPlate"))
                .containerBackground(.fill, for: .widget)
        case .accessoryInline:
            Text(String(format: "Kolhydrater: %.1f gk", entry.totalCarbs))
                .widgetURL(URL(string: "kolkalk://FoodPlate"))
                .containerBackground(.fill, for: .widget)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("Totalt kolhydrater")
                    .font(.headline)
                Text(String(format: "%.1f gram", entry.totalCarbs))
                    .font(.body)
            }
            .widgetURL(URL(string: "kolkalk://FoodPlate"))
            .containerBackground(.fill, for: .widget)
        default:
            Text("Unsupported")
                .containerBackground(.fill, for: .widget)
        }
    }
}

// MARK: - AddFoodComplication

struct AddFoodComplication: Widget {
    let kind: String = "AddFoodComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AddFoodProvider()) { entry in
            AddFoodEntryView(entry: entry)
        }
        .configurationDisplayName("Lägg till livsmedel")
        .description("Gå direkt till lägg till livsmedel.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct AddFoodProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let timeline = Timeline(entries: [SimpleEntry(date: Date())], policy: .never)
        completion(timeline)
    }
}

struct AddFoodEntryView: View {
    var entry: SimpleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Använd SF Symbol med en cirkel (ej fylld)
            Image(systemName: "plus.circle")
                .font(.system(size: 24, weight: .thin)) // Justera storlek och vikt
                .widgetURL(URL(string: "kolkalk://addFood"))
                .containerBackground(.fill, for: .widget)
        case .accessoryCorner:
            // Använd SF Symbol med en cirkel (ej fylld)
            Image(systemName: "plus.circle")
                .font(.system(size: 24, weight: .thin)) // Justera storlek och vikt
                .widgetLabel("Lägg till")
                .widgetURL(URL(string: "kolkalk://addFood"))
                .containerBackground(.fill, for: .widget)
        case .accessoryInline:
            Text("Lägg till livsmedel")
                .widgetURL(URL(string: "kolkalk://addFood"))
                .containerBackground(.fill, for: .widget)
        case .accessoryRectangular:
            Text("Lägg till livsmedel")
                .widgetURL(URL(string: "kolkalk://addFood"))
                .containerBackground(.fill, for: .widget)
        default:
            Text("Unsupported")
                .containerBackground(.fill, for: .widget)
        }
    }
}

// MARK: - EmptyAndAddFoodComplication

struct EmptyAndAddFoodComplication: Widget {
    let kind: String = "EmptyAndAddFoodComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EmptyAndAddFoodProvider()) { entry in
            EmptyAndAddFoodEntryView(entry: entry)
        }
        .configurationDisplayName("Töm och lägg till livsmedel")
        .description("Töm tallriken och lägg till livsmedel.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct EmptyAndAddFoodProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let timeline = Timeline(entries: [SimpleEntry(date: Date())], policy: .never)
        completion(timeline)
    }
}

struct EmptyAndAddFoodEntryView: View {
    var entry: SimpleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Använd SF Symbol med en cirkel (ej fylld) och soptunna
             ZStack {
                 Image(systemName: "circle")
                     .font(.system(size: 24, weight: .thin)) // Justera storlek och vikt
                 Image(systemName: "trash")
                     .font(.system(size: 12, weight: .thin)) // Justera storlek och vikt
             }
             .widgetURL(URL(string: "kolkalk://emptyAndAddFood"))
             .containerBackground(.fill, for: .widget)
        case .accessoryCorner:
            // Använd SF Symbol med en cirkel (ej fylld) och soptunna
            ZStack {
                Image(systemName: "circle")
                    .font(.system(size: 24, weight: .thin)) // Justera storlek och vikt
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .thin)) // Justera storlek och vikt
            }
            .widgetLabel("Töm & Lägg")
            .widgetURL(URL(string: "kolkalk://emptyAndAddFood"))
            .containerBackground(.fill, for: .widget)
        case .accessoryInline:
            Text("Töm & Lägg till")
                .widgetURL(URL(string: "kolkalk://emptyAndAddFood"))
                .containerBackground(.fill, for: .widget)
        case .accessoryRectangular:
            Text("Töm tallriken och lägg till livsmedel")
                .widgetURL(URL(string: "kolkalk://emptyAndAddFood"))
                .containerBackground(.fill, for: .widget)
        default:
            Text("Unsupported")
                .containerBackground(.fill, for: .widget)
        }
    }
}

// MARK: - SimpleEntry

struct SimpleEntry: TimelineEntry {
    let date: Date
}

// MARK: - WidgetBundle

@main
struct KomplikationBundle: WidgetBundle {
    var body: some Widget {
        ExistingComplication()
        AddFoodComplication()
        EmptyAndAddFoodComplication()
    }
}
