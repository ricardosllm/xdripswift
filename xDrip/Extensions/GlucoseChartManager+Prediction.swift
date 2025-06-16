import Foundation
import SwiftCharts
import UIKit
import os.log
import CoreData

// MARK: - Prediction Extensions for GlucoseChartManager

extension GlucoseChartManager {
    
    /// Generates prediction chart points for display on the glucose chart using iAPS algorithms
    /// - Parameters:
    ///   - bgReadings: Array of BgReading objects for prediction input
    ///   - endDate: The end date of the chart (latest time displayed)
    /// - Returns: Array of ChartPoint objects representing glucose predictions
    func generatePredictionChartPoints(bgReadings: [BgReading], endDate: Date) -> [ChartPoint] {
        
        // Check if iAPS predictions are enabled in user settings
        guard UserDefaults.standard.showIAPSPredictions else {
            return []
        }
        
        // Filter out any readings with invalid data
        let validReadings = bgReadings.filter { reading in
            // Ensure the reading has valid data
            return reading.calculatedValue > 0 &&
                   reading.calculatedValue < 1000 && // sanity check for unrealistic values
                   reading.timeStamp.timeIntervalSinceNow < 0 // ensure it's not a future date
        }
        
        guard !validReadings.isEmpty else {
            os_log("No valid readings found for predictions", log: .default, type: .info)
            return []
        }
        
        // Log the readings being used for predictions
        os_log("Generating iAPS predictions with %{public}d valid readings", log: .default, type: .info, validReadings.count)
        
        // Get prediction time horizon from user settings (default 1.5 hours)
        let predictionHours = UserDefaults.standard.iAPSPredictionHours
        
        // Get treatment entries for IOB/COB calculations
        let treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-24 * 3600) // Last 24 hours
        let treatments = treatmentEntryAccessor.getTreatments(fromDate: startTime, toDate: endTime, on: coreDataManager.mainManagedObjectContext)
        
        // Initialize iAPS prediction manager
        let iAPSManager = iAPSPredictionManager()
        
        // Generate predictions using iAPS algorithms
        guard let predictionResult = iAPSManager.generatePredictions(glucose: validReadings, treatments: treatments) else {
            os_log("iAPS prediction generation failed", log: .default, type: .error)
            return []
        }
        
        // Log prediction arrays to understand their length
        os_log("iAPS Prediction arrays - IOB: %{public}d values, COB: %{public}d values, UAM: %{public}d values, ZT: %{public}d values", 
               log: .default, type: .info,
               predictionResult.iob.count, predictionResult.cob.count, 
               predictionResult.uam.count, predictionResult.zt.count)
        
        // Convert iAPS predictions to chart points
        var chartPoints: [ChartPoint] = []
        let now = Date()
        
        // Create a simple date formatter for the x-axis
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        // Helper function to create chart points from prediction values
        func createChartPoints(from predictions: [Double], startTime: Date, intervalMinutes: Int) -> [ChartPoint] {
            var points: [ChartPoint] = []
            
            for (index, value) in predictions.enumerated() {
                let timeStamp = startTime.addingTimeInterval(Double(index * intervalMinutes * 60))
                // Only include future predictions (beyond current time)
                if timeStamp > now {
                    let xValue = ChartAxisValueDate(date: timeStamp, formatter: timeFormatter)
                    // Convert value to user's preferred unit (predictions are in mg/dL)
                    let convertedValue = value.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                    let yValue = ChartAxisValueDouble(convertedValue)
                    let point = ChartPoint(x: xValue, y: yValue)
                    points.append(point)
                    
                    // Log the first few points for debugging
                    if points.count <= 3 {
                        os_log("Creating prediction point #%{public}d: %{public}@ = %.1f mg/dL", log: .default, type: .info, points.count, timeStamp.description, value)
                    }
                }
            }
            
            return points
        }
        
        // Use the current time as start time for predictions
        let predictionStartTime = now
        
        // Determine which prediction line(s) to show
        let showIOB = UserDefaults.standard.showIOBPrediction
        let showCOB = UserDefaults.standard.showCOBPrediction
        let showUAM = UserDefaults.standard.showUAMPrediction
        
        os_log("Prediction display settings - IOB: %{public}@, COB: %{public}@, UAM: %{public}@", 
               log: .default, type: .info, 
               showIOB.description, showCOB.description, showUAM.description)
        
        // If no specific lines are selected, show the IOB prediction as default
        if !showIOB && !showCOB && !showUAM {
            os_log("No specific predictions selected, showing IOB as default", log: .default, type: .info)
            let iobPredictions = createChartPoints(
                from: predictionResult.iob,
                startTime: predictionStartTime,
                intervalMinutes: 5
            )
            chartPoints.append(contentsOf: iobPredictions)
            os_log("Added %{public}d IOB prediction points as default", log: .default, type: .info, iobPredictions.count)
        } else {
            // Show selected prediction lines
            if showIOB {
                let iobPredictions = createChartPoints(
                    from: predictionResult.iob,
                    startTime: predictionStartTime,
                    intervalMinutes: 5
                )
                chartPoints.append(contentsOf: iobPredictions)
            }
            
            if showCOB {
                let cobPredictions = createChartPoints(
                    from: predictionResult.cob,
                    startTime: predictionStartTime,
                    intervalMinutes: 5
                )
                chartPoints.append(contentsOf: cobPredictions)
            }
            
            if showUAM {
                let uamPredictions = createChartPoints(
                    from: predictionResult.uam,
                    startTime: predictionStartTime,
                    intervalMinutes: 5
                )
                chartPoints.append(contentsOf: uamPredictions)
            }
        }
        
        // Filter to only show predictions within the requested time horizon
        let maxPredictionTime = now.addingTimeInterval(predictionHours * 3600)
        let unfilteredCount = chartPoints.count
        chartPoints = chartPoints.filter { point in
            if let xValue = point.x as? ChartAxisValueDate {
                return xValue.date <= maxPredictionTime
            }
            return false
        }
        
        os_log("Prediction filtering - Before: %{public}d points, After: %{public}d points (max time: %{public}@, prediction hours: %.1f)", 
               log: .default, type: .info,
               unfilteredCount, chartPoints.count, maxPredictionTime.description, predictionHours)
        
        // Log successful prediction generation
        if !chartPoints.isEmpty {
            os_log("Successfully generated %{public}d iAPS prediction points", log: .default, type: .info, chartPoints.count)
            
            // Log first and last prediction points for debugging
            if let firstPoint = chartPoints.first, 
               let firstX = firstPoint.x as? ChartAxisValueDate,
               let firstY = firstPoint.y as? ChartAxisValueDouble {
                let displayValue = firstY.scalar.mgDlToMmol(mgDl: !UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                os_log("First prediction point: %{public}@ at %.1f (displayed as %.1f)", log: .default, type: .info, firstX.date.description, firstY.scalar, displayValue)
            }
            
            if let lastPoint = chartPoints.last,
               let lastX = lastPoint.x as? ChartAxisValueDate,
               let lastY = lastPoint.y as? ChartAxisValueDouble {
                let displayValue = lastY.scalar.mgDlToMmol(mgDl: !UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                os_log("Last prediction point: %{public}@ at %.1f (displayed as %.1f)", log: .default, type: .info, lastX.date.description, lastY.scalar, displayValue)
            }
        } else {
            os_log("No iAPS prediction points generated - check if predictions are being filtered out", log: .default, type: .info)
        }
        
        return chartPoints
    }
    
    /// Creates a prediction chart layer for display on the glucose chart
    /// - Parameters:
    ///   - predictionChartPoints: Array of prediction chart points
    ///   - xAxisLayer: The chart's x-axis layer
    ///   - yAxisLayer: The chart's y-axis layer
    /// - Returns: ChartPointsLineLayer configured for prediction display
    func createPredictionLineLayer(
        predictionChartPoints: [ChartPoint],
        xAxisLayer: ChartAxisLayer,
        yAxisLayer: ChartAxisLayer
    ) -> ChartPointsLineLayer<ChartPoint>? {
        
        guard !predictionChartPoints.isEmpty else { 
            os_log("createPredictionLineLayer: No prediction points to display", log: .default, type: .info)
            return nil 
        }
        
        os_log("createPredictionLineLayer: Creating layer with %{public}d points", log: .default, type: .info, predictionChartPoints.count)
        
        // Configure prediction line appearance based on which predictions are shown
        let predictionLineWidth = CGFloat(2.0) // Default line width
        
        // Determine line colors based on what's being shown
        var lineModels: [ChartLineModel] = []
        
        // If showing multiple prediction types, use different colors
        if UserDefaults.standard.showIOBPrediction ||
           UserDefaults.standard.showCOBPrediction ||
           UserDefaults.standard.showUAMPrediction {
            
            // For now, use a single color for all predictions
            // In the future, we could separate the chart points by type
            let predictionLineModel = ChartLineModel(
                chartPoints: predictionChartPoints,
                lineColor: UIColor.systemBlue.withAlphaComponent(0.7),
                lineWidth: predictionLineWidth,
                animDuration: 0.3,
                animDelay: 0.0,
                dashPattern: [6, 3] // Dashed line pattern: 6px dash, 3px gap
            )
            lineModels.append(predictionLineModel)
            
        } else {
            // Single prediction line with default styling
            let predictionLineModel = ChartLineModel(
                chartPoints: predictionChartPoints,
                lineColor: UIColor.systemBlue.withAlphaComponent(0.7),
                lineWidth: predictionLineWidth,
                animDuration: 0.3,
                animDelay: 0.0,
                dashPattern: [8, 4] // Dotted line pattern: 8px dash, 4px gap
            )
            lineModels.append(predictionLineModel)
        }
        
        // Create and return the line layer
        let lineLayer = ChartPointsLineLayer(
            xAxis: xAxisLayer.axis,
            yAxis: yAxisLayer.axis,
            lineModels: lineModels
        )
        
        os_log("createPredictionLineLayer: Successfully created prediction line layer", log: .default, type: .info)
        
        return lineLayer
    }
    
    /// Creates confidence band points for uncertainty visualization
    private func createConfidenceBandPoints(from predictionPoints: [ChartPoint]) -> [ChartPoint] {
        guard predictionPoints.count >= 2 else { return [] }
        
        var confidenceBandPoints: [ChartPoint] = []
        
        // Create upper confidence band (simplified - just add 10% uncertainty)
        for point in predictionPoints {
            if let yValue = point.y as? ChartAxisValueDouble {
                let upperValue = yValue.scalar * 1.1
                let upperPoint = ChartPoint(
                    x: point.x,
                    y: ChartAxisValueDouble(upperValue)
                )
                confidenceBandPoints.append(upperPoint)
            }
        }
        
        // Create lower confidence band (reverse order for proper fill)
        for point in predictionPoints.reversed() {
            if let yValue = point.y as? ChartAxisValueDouble {
                let lowerValue = yValue.scalar * 0.9
                let lowerPoint = ChartPoint(
                    x: point.x,
                    y: ChartAxisValueDouble(lowerValue)
                )
                confidenceBandPoints.append(lowerPoint)
            }
        }
        
        return confidenceBandPoints
    }
}

// MARK: - UserDefaults Extensions for Prediction Settings

extension UserDefaults {
    
    /// Whether glucose prediction is enabled (old setting - deprecated)
    var predictionEnabled: Bool {
        get { bool(forKey: "predictionEnabled") }
        set { set(newValue, forKey: "predictionEnabled") }
    }
    
    /// Prediction time horizon in minutes (default: 30)
    var predictionTimeHorizon: Int {
        get { 
            let value = integer(forKey: "predictionTimeHorizon")
            return value > 0 ? value : 30
        }
        set { set(newValue, forKey: "predictionTimeHorizon") }
    }
    
    /// Whether to show prediction confidence bands
    var showPredictionConfidence: Bool {
        get { bool(forKey: "showPredictionConfidence") }
        set { set(newValue, forKey: "showPredictionConfidence") }
    }
    
    /// Prediction line color
    var predictionLineColor: UIColor {
        get {
            if let colorData = data(forKey: "predictionLineColor"),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
                return color
            }
            return UIColor.systemBlue.withAlphaComponent(0.7)
        }
        set {
            if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false) {
                set(colorData, forKey: "predictionLineColor")
            }
        }
    }
    
    /// Prediction line width (default: 2.0)
    var predictionLineWidth: CGFloat {
        get {
            let value = double(forKey: "predictionLineWidth")
            return value > 0 ? CGFloat(value) : 2.0
        }
        set { set(Double(newValue), forKey: "predictionLineWidth") }
    }
    
    /// Whether low glucose prediction alerts are enabled
    var lowGlucosePredictionEnabled: Bool {
        get { bool(forKey: "lowGlucosePredictionEnabled") }
        set { set(newValue, forKey: "lowGlucosePredictionEnabled") }
    }
    
    /// Low glucose prediction threshold in mg/dL (default: 70.0)
    var lowGlucosePredictionThreshold: Double {
        get {
            let value = double(forKey: "lowGlucosePredictionThreshold")
            return value > 0 ? value : 70.0
        }
        set { set(newValue, forKey: "lowGlucosePredictionThreshold") }
    }
    
    // MARK: - iAPS Prediction Settings
    
    /// Whether iAPS predictions are enabled
    var showIAPSPredictions: Bool {
        get { bool(forKey: "showIAPSPredictions") }
        set { set(newValue, forKey: "showIAPSPredictions") }
    }
    
    /// iAPS prediction time horizon in hours (default: 1.5 hours = 50% of 3 hour chart)
    var iAPSPredictionHours: Double {
        get {
            let value = double(forKey: "iAPSPredictionHours")
            return value > 0 ? value : 1.5
        }
        set { set(newValue, forKey: "iAPSPredictionHours") }
    }
    
    /// Show IOB-only prediction line
    var showIOBPrediction: Bool {
        get { bool(forKey: "showIOBPrediction") }
        set { set(newValue, forKey: "showIOBPrediction") }
    }
    
    /// Show COB prediction line
    var showCOBPrediction: Bool {
        get { bool(forKey: "showCOBPrediction") }
        set { set(newValue, forKey: "showCOBPrediction") }
    }
    
    /// Show UAM prediction line
    var showUAMPrediction: Bool {
        get { bool(forKey: "showUAMPrediction") }
        set { set(newValue, forKey: "showUAMPrediction") }
    }
}

