import ClockKit
import SwiftUI

class ComplicationController: NSObject, CLKComplicationDataSource {
    // MARK: - Tidslinjekonfiguration

    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([])
    }

    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }

    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }

    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }

    // MARK: - Tidslinjepopulation

    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        let totalCarbs = Plate.shared.totalCarbs

        let template = createTemplate(for: complication.family, totalCarbs: totalCarbs)

        let timelineEntry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)

        handler(timelineEntry)
    }

    // MARK: - Platshållarmallar

    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let sampleTemplate = createTemplate(for: complication.family, totalCarbs: 0.0)
        handler(sampleTemplate)
    }

    // MARK: - Hjälpmetod

    private func createTemplate(for family: CLKComplicationFamily, totalCarbs: Double) -> CLKComplicationTemplate {
        let totalCarbsText = CLKSimpleTextProvider(text: String(format: "%.1f gk", totalCarbs))

        switch family {
        case .modularSmall:
            return CLKComplicationTemplateModularSmallSimpleText(textProvider: totalCarbsText)

        case .modularLarge:
            let headerText = CLKSimpleTextProvider(text: "Kolhydrater")
            return CLKComplicationTemplateModularLargeStandardBody(headerTextProvider: headerText, body1TextProvider: totalCarbsText)

        case .utilitarianSmall:
            return CLKComplicationTemplateUtilitarianSmallFlat(textProvider: totalCarbsText)

        case .utilitarianLarge:
            return CLKComplicationTemplateUtilitarianLargeFlat(textProvider: totalCarbsText)

        case .circularSmall:
            return CLKComplicationTemplateCircularSmallSimpleText(textProvider: totalCarbsText)

        case .extraLarge:
            return CLKComplicationTemplateExtraLargeSimpleText(textProvider: totalCarbsText)

        case .graphicCorner:
            return CLKComplicationTemplateGraphicCornerStackText(
                innerTextProvider: CLKSimpleTextProvider(text: "Gk"),
                outerTextProvider: totalCarbsText
            )

        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularView(
                ComplicationView(totalCarbs: totalCarbs)
            )

        case .graphicRectangular:
            return CLKComplicationTemplateGraphicRectangularStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: "Kolhydrater"),
                body1TextProvider: totalCarbsText
            )

        case .graphicBezel:
            let circularTemplate = CLKComplicationTemplateGraphicCircularView(
                ComplicationView(totalCarbs: totalCarbs)
            )
            return CLKComplicationTemplateGraphicBezelCircularText(
                circularTemplate: circularTemplate,
                textProvider: totalCarbsText
            )

        default:
            return CLKComplicationTemplateModularSmallSimpleText(textProvider: totalCarbsText)
        }
    }
}

// SwiftUI-vy för komplikationer
struct ComplicationView: View {
    var totalCarbs: Double

    var body: some View {
        Text(String(format: "%.1f gk", totalCarbs))
            .font(.system(size: 12))
    }
}
