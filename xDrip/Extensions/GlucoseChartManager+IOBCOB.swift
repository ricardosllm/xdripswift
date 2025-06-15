import Foundation
import SwiftCharts
import UIKit
import os.log

// MARK: - Temporary IOB/COB Structures (until calculators are added to project)

struct IOBValue {
    let iob: Double
    let activity: Double
    let glucoseDropRatePerMinute: Double
    let lastCalculated: Date
}

struct COBValue {
    let cob: Double
    let absorptionRate: Double
    let glucoseRiseRatePerMinute: Double
    let lastCalculated: Date
}

// MARK: - IOB/COB Display Extensions for GlucoseChartManager

extension GlucoseChartManager {
    
    /// Creates IOB/COB overlay view for the chart
    /// - Parameters:
    ///   - containerView: The view to add the overlay to
    ///   - chartFrame: The frame of the chart
    /// - Returns: The created overlay view
    func createIOBCOBOverlay(in containerView: UIView, chartFrame: CGRect) -> UIView? {
        
        // Check if IOB/COB display is enabled
        guard UserDefaults.standard.showIOBCOBOnChart else { return nil }
        
        // Remove any existing overlay
        containerView.subviews.forEach { view in
            if view.tag == 999 { // IOB/COB overlay tag
                view.removeFromSuperview()
            }
        }
        
        // Create overlay container
        let overlayView = UIView()
        overlayView.tag = 999
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        overlayView.layer.cornerRadius = 8
        overlayView.layer.borderColor = UIColor.systemGray3.cgColor
        overlayView.layer.borderWidth = 0.5
        
        // Create IOB/COB label
        let iobCobLabel = UILabel()
        iobCobLabel.translatesAutoresizingMaskIntoConstraints = false
        iobCobLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        iobCobLabel.textColor = UIColor.label
        iobCobLabel.textAlignment = .left
        
        // Calculate current IOB and COB
        let iobCobText = calculateCurrentIOBCOBText()
        iobCobLabel.attributedText = iobCobText
        
        // Add label to overlay
        overlayView.addSubview(iobCobLabel)
        
        // Add overlay to container
        containerView.addSubview(overlayView)
        
        // Set constraints
        NSLayoutConstraint.activate([
            // Position overlay in top-left corner with padding
            overlayView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            overlayView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            // Label constraints within overlay
            iobCobLabel.topAnchor.constraint(equalTo: overlayView.topAnchor, constant: 8),
            iobCobLabel.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor, constant: -8),
            iobCobLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 12),
            iobCobLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -12)
        ])
        
        return overlayView
    }
    
    /// Calculates current IOB and COB values and formats them for display
    private func calculateCurrentIOBCOBText() -> NSAttributedString {
        
        // TODO: Use actual IOB/COB calculators when added to project
        // For now, return placeholder values
        let iobValue = IOBValue(iob: 2.5, activity: 0.8, glucoseDropRatePerMinute: 0.5, lastCalculated: Date())
        let cobValue = COBValue(cob: 35.0, absorptionRate: 10.0, glucoseRiseRatePerMinute: 0.3, lastCalculated: Date())
        
        /* When calculators are added to project:
        guard let iobCalculator = IOBCalculator(coreDataManager: coreDataManager),
              let cobCalculator = COBCalculator(coreDataManager: coreDataManager) else {
            return NSAttributedString(string: "IOB/COB unavailable")
        }
        */
        
        /* When calculators are added:
        // Get user settings
        let insulinType = InsulinType.fromString(UserDefaults.standard.insulinType) ?? .rapid
        let insulinSensitivity = UserDefaults.standard.insulinSensitivityMgDl
        let carbRatio = UserDefaults.standard.carbRatio
        let carbAbsorptionRate = UserDefaults.standard.carbAbsorptionRate
        let carbAbsorptionDelay = UserDefaults.standard.carbAbsorptionDelay
        
        // Calculate current IOB
        let iobValue = iobCalculator.calculateIOB(
            at: Date(),
            insulinType: insulinType,
            insulinSensitivity: insulinSensitivity
        )
        
        // Calculate current COB
        let cobValue = cobCalculator.calculateCOB(
            at: Date(),
            absorptionRate: carbAbsorptionRate,
            delay: carbAbsorptionDelay,
            carbRatio: carbRatio,
            insulinSensitivity: insulinSensitivity
        )
        */
        
        // Format the display text
        let attributedString = NSMutableAttributedString()
        
        // IOB section
        let iobTitle = NSAttributedString(string: "IOB: ", attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ])
        attributedString.append(iobTitle)
        
        let iobValueText = String(format: "%.1fU", iobValue.iob)
        let iobValueAttr = NSAttributedString(string: iobValueText, attributes: [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.systemBlue
        ])
        attributedString.append(iobValueAttr)
        
        // Add arrow for IOB activity
        if iobValue.activity > 0.01 {
            let arrow = iobValue.glucoseDropRatePerMinute > 0.5 ? " ↓↓" : " ↓"
            let arrowAttr = NSAttributedString(string: arrow, attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.systemBlue
            ])
            attributedString.append(arrowAttr)
        }
        
        // Separator
        attributedString.append(NSAttributedString(string: "  |  "))
        
        // COB section
        let cobTitle = NSAttributedString(string: "COB: ", attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ])
        attributedString.append(cobTitle)
        
        let cobValueText = String(format: "%.0fg", cobValue.cob)
        let cobValueAttr = NSAttributedString(string: cobValueText, attributes: [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.systemOrange
        ])
        attributedString.append(cobValueAttr)
        
        // Add arrow for COB activity
        if cobValue.absorptionRate > 0.1 {
            let arrow = cobValue.glucoseRiseRatePerMinute > 0.5 ? " ↑↑" : " ↑"
            let arrowAttr = NSAttributedString(string: arrow, attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.systemOrange
            ])
            attributedString.append(arrowAttr)
        }
        
        return attributedString
    }
    
    /// Generates IOB trend line chart points
    func generateIOBTrendChartPoints(endDate: Date, chartWidthHours: Int) -> [ChartPoint] {
        
        guard UserDefaults.standard.showIOBTrendOnChart else {
            return []
        }
        
        // TODO: Implement when IOB calculator is added to project
        return []
        
        /* When calculator is available:
        guard let iobCalculator = IOBCalculator(coreDataManager: coreDataManager) else {
            return []
        }
        
        let insulinType = InsulinType.fromString(UserDefaults.standard.insulinType) ?? .rapid
        let insulinSensitivity = UserDefaults.standard.insulinSensitivityMgDl
        
        // Calculate IOB curve for the next 3 hours
        let duration: TimeInterval = 3 * 3600
        let iobCurve = iobCalculator.calculateIOBCurve(
            from: Date(),
            duration: duration,
            interval: 300, // 5 minutes
            insulinType: insulinType,
            insulinSensitivity: insulinSensitivity
        )
        
        // Convert to chart points (scaled to fit on glucose chart)
        // We'll scale IOB to show on the same axis as glucose
        // 1 unit of IOB = ISF mg/dL equivalent
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        return iobCurve.map { iobValue in
            let xValue = ChartAxisValueDate(date: iobValue.lastCalculated, formatter: formatter)
            
            // Scale IOB to glucose equivalent for display
            // This shows "how much glucose drop is pending"
            let glucoseEquivalent = iobValue.iob * insulinSensitivity
            let scaledValue = UserDefaults.standard.bloodGlucoseUnitIsMgDl
                ? glucoseEquivalent
                : glucoseEquivalent.mgDlToMmol()
            
            let yValue = ChartAxisValueDouble(scaledValue)
            
            return ChartPoint(x: xValue, y: yValue)
        }
        */
    }
    
    /// Generates COB trend line chart points
    func generateCOBTrendChartPoints(endDate: Date, chartWidthHours: Int) -> [ChartPoint] {
        
        guard UserDefaults.standard.showCOBTrendOnChart else {
            return []
        }
        
        // TODO: Implement when COB calculator is added to project
        return []
        
        /* When calculator is available:
        guard let cobCalculator = COBCalculator(coreDataManager: coreDataManager) else {
            return []
        }
        
        let carbRatio = UserDefaults.standard.carbRatio
        let insulinSensitivity = UserDefaults.standard.insulinSensitivityMgDl
        let carbAbsorptionRate = UserDefaults.standard.carbAbsorptionRate
        let carbAbsorptionDelay = UserDefaults.standard.carbAbsorptionDelay
        
        // Calculate COB curve for the next 3 hours
        let duration: TimeInterval = 3 * 3600
        let cobCurve = cobCalculator.calculateCOBCurve(
            from: Date(),
            duration: duration,
            interval: 300, // 5 minutes
            absorptionRate: carbAbsorptionRate,
            delay: carbAbsorptionDelay,
            carbRatio: carbRatio,
            insulinSensitivity: insulinSensitivity
        )
        
        // Convert to chart points (scaled to fit on glucose chart)
        // We'll scale COB to show glucose impact
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        return cobCurve.map { cobValue in
            let xValue = ChartAxisValueDate(date: cobValue.lastCalculated, formatter: formatter)
            
            // Scale COB to glucose equivalent for display
            // This shows "how much glucose rise is pending"
            let glucoseEquivalent = cobValue.cob * (insulinSensitivity / carbRatio)
            let scaledValue = UserDefaults.standard.bloodGlucoseUnitIsMgDl
                ? glucoseEquivalent
                : glucoseEquivalent.mgDlToMmol()
            
            let yValue = ChartAxisValueDouble(scaledValue)
            
            return ChartPoint(x: xValue, y: yValue)
        }
        */
    }
    
    /// Creates IOB trend line layer
    func createIOBTrendLineLayer(
        iobChartPoints: [ChartPoint],
        xAxisLayer: ChartAxisLayer,
        yAxisLayer: ChartAxisLayer
    ) -> ChartPointsLineLayer<ChartPoint>? {
        
        guard !iobChartPoints.isEmpty else { return nil }
        
        // Configure IOB line appearance - blue color
        let iobLineModel = ChartLineModel(
            chartPoints: iobChartPoints,
            lineColor: UIColor.systemBlue.withAlphaComponent(0.7),
            lineWidth: 2.0,
            animDuration: 0.3,
            animDelay: 0.0,
            dashPattern: [4, 2] // Smaller dash pattern than predictions
        )
        
        return ChartPointsLineLayer(
            xAxis: xAxisLayer.axis,
            yAxis: yAxisLayer.axis,
            lineModels: [iobLineModel]
        )
    }
    
    /// Creates COB trend line layer
    func createCOBTrendLineLayer(
        cobChartPoints: [ChartPoint],
        xAxisLayer: ChartAxisLayer,
        yAxisLayer: ChartAxisLayer
    ) -> ChartPointsLineLayer<ChartPoint>? {
        
        guard !cobChartPoints.isEmpty else { return nil }
        
        // Configure COB line appearance - orange color
        let cobLineModel = ChartLineModel(
            chartPoints: cobChartPoints,
            lineColor: UIColor.systemOrange.withAlphaComponent(0.7),
            lineWidth: 2.0,
            animDuration: 0.3,
            animDelay: 0.0,
            dashPattern: [4, 2] // Smaller dash pattern than predictions
        )
        
        return ChartPointsLineLayer(
            xAxis: xAxisLayer.axis,
            yAxis: yAxisLayer.axis,
            lineModels: [cobLineModel]
        )
    }
}