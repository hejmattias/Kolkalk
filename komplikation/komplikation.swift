import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), totalCarbs: 0.0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let totalCarbs = fetchTotalCarbs()
        let entry = SimpleEntry(date: Date(), totalCarbs: totalCarbs)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let totalCarbs = fetchTotalCarbs()
        let entry = SimpleEntry(date: Date(), totalCarbs: totalCarbs)
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

struct SimpleEntry: TimelineEntry {
    let date: Date
    let totalCarbs: Double
}

struct komplikationEntryView: View {
    let entry: SimpleEntry

    @AppStorage("totalCarbs", store: UserDefaults(suiteName: "group.mg.kolkalk")) var totalCarbs: Double = 0.0

    var body: some View {
        Text(String(format: "%.1f gk", totalCarbs))
            .containerBackground(.fill, for: .widget) // Korrigerat anrop
    }
}

@main
struct komplikation: Widget {
    let kind: String = "komplikation"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            komplikationEntryView(entry: entry)
        }
        .configurationDisplayName("Kolhydratkomplikation")
        .description("Visar totala gram kolhydrater på tallriken.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
