import UIKit
import CoreData

/// View controller to display MDI recommendation history
class MDIHistoryViewController: UIViewController {
    
    // MARK: - Properties
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var statisticsView: UIView!
    @IBOutlet weak var acceptanceRateLabel: UILabel!
    @IBOutlet weak var totalCountLabel: UILabel!
    
    private var coreDataManager: CoreDataManager?
    private var recommendations: [MDIRecommendationHistory] = []
    private let dateFormatter = DateFormatter()
    private let timeFormatter = DateFormatter()
    
    private enum FilterType: Int {
        case all = 0
        case accepted = 1
        case dismissed = 2
        case pending = 3
    }
    
    private var currentFilter: FilterType = .all
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "MDI History"
        setupFormatters()
        setupUI()
        loadRecommendations()
        updateStatistics()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Refresh data when view appears
        loadRecommendations()
        updateStatistics()
    }
    
    // MARK: - Setup
    
    private func setupFormatters() {
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
    }
    
    private func setupUI() {
        // Configure table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        
        // Configure segmented control
        segmentedControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        
        // Add refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        // Style statistics view
        statisticsView.layer.cornerRadius = 8
        statisticsView.layer.borderWidth = 1
        statisticsView.layer.borderColor = UIColor.systemGray4.cgColor
        
        // Add export button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(exportHistory)
        )
    }
    
    func configure(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: - Data Loading
    
    private func loadRecommendations() {
        guard let coreDataManager = coreDataManager else { return }
        
        let request: NSFetchRequest<MDIRecommendationHistory> = MDIRecommendationHistory.fetchRequest()
        
        // Apply filter
        switch currentFilter {
        case .all:
            request.predicate = nil
        case .accepted:
            request.predicate = NSPredicate(format: "status == %@ OR status == %@",
                                          RecommendationStatus.accepted.stringValue,
                                          RecommendationStatus.modified.stringValue)
        case .dismissed:
            request.predicate = NSPredicate(format: "status == %@",
                                          RecommendationStatus.dismissed.stringValue)
        case .pending:
            request.predicate = NSPredicate(format: "status == %@ AND expiresAt > %@",
                                          RecommendationStatus.pending.stringValue,
                                          Date() as NSDate)
        }
        
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = 500 // Limit to last 500 recommendations
        
        do {
            recommendations = try coreDataManager.mainManagedObjectContext.fetch(request)
            tableView.reloadData()
        } catch {
            print("Error fetching recommendations: \(error)")
        }
    }
    
    private func updateStatistics() {
        guard let coreDataManager = coreDataManager else { return }
        
        let statistics = MDIRecommendationHistory.getStatistics(
            for: 30,
            managedObjectContext: coreDataManager.mainManagedObjectContext
        )
        
        acceptanceRateLabel.text = String(format: "%.0f%% Accepted", statistics.acceptanceRate * 100)
        totalCountLabel.text = "\(statistics.totalRecommendations) Total (30 days)"
    }
    
    // MARK: - Actions
    
    @objc private func filterChanged() {
        currentFilter = FilterType(rawValue: segmentedControl.selectedSegmentIndex) ?? .all
        loadRecommendations()
    }
    
    @objc private func refreshData() {
        loadRecommendations()
        updateStatistics()
        tableView.refreshControl?.endRefreshing()
    }
    
    @objc private func exportHistory() {
        guard let coreDataManager = coreDataManager else { return }
        
        // Get last 90 days of data
        let startDate = Date().addingTimeInterval(-90 * 24 * 3600)
        let history = MDIRecommendationHistory.fetchRecommendations(
            from: startDate,
            to: Date(),
            managedObjectContext: coreDataManager.mainManagedObjectContext
        )
        
        // Create CSV
        var csv = "Date,Time,Type,Recommended Dose,Recommended Carbs,Status,Actual Dose,Actual Carbs,Glucose,IOB,COB,Reason\n"
        
        for item in history {
            let date = dateFormatter.string(from: item.timestamp ?? Date())
            let time = timeFormatter.string(from: item.timestamp ?? Date())
            let type = item.recommendationType ?? ""
            let recDose = String(format: "%.1f", item.recommendedDose)
            let recCarbs = String(format: "%.0f", item.recommendedCarbs)
            let status = item.status ?? ""
            let actualDose = String(format: "%.1f", item.actualDoseTaken)
            let actualCarbs = String(format: "%.0f", item.actualCarbsTaken)
            let glucose = String(format: "%.0f", item.glucoseAtTime)
            let iob = String(format: "%.1f", item.iobAtTime)
            let cob = String(format: "%.0f", item.cobAtTime)
            let reason = item.reason?.replacingOccurrences(of: ",", with: ";") ?? ""
            
            csv += "\(date),\(time),\(type),\(recDose),\(recCarbs),\(status),\(actualDose),\(actualCarbs),\(glucose),\(iob),\(cob),\(reason)\n"
        }
        
        // Share CSV
        let fileName = "MDI_History_\(Date().ISO8601Format()).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csv.write(to: path, atomically: true, encoding: .utf8)
            
            let activityController = UIActivityViewController(
                activityItems: [path],
                applicationActivities: nil
            )
            
            // For iPad
            if let popover = activityController.popoverPresentationController {
                popover.barButtonItem = navigationItem.rightBarButtonItem
            }
            
            present(activityController, animated: true)
        } catch {
            showAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension MDIHistoryViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // Group by date
        let dates = Set<String>(recommendations.compactMap { recommendation in
            guard let timestamp = recommendation.timestamp else { return nil }
            return dateFormatter.string(from: timestamp)
        })
        return dates.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionDate = getSectionDate(for: section)
        return recommendations.filter { recommendation in
            guard let timestamp = recommendation.timestamp else { return false }
            return dateFormatter.string(from: timestamp) == sectionDate
        }.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return getSectionDate(for: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "HistoryCell")
        
        let recommendation = getRecommendation(for: indexPath)
        
        // Configure cell
        configureCell(cell, with: recommendation)
        
        return cell
    }
    
    private func configureCell(_ cell: UITableViewCell, with recommendation: MDIRecommendationHistory) {
        // Time
        let time = timeFormatter.string(from: recommendation.timestamp ?? Date())
        
        // Main text
        var text = time + " - " + recommendation.displayDescription
        
        // Add status indicator
        if let status = recommendation.status {
            switch status {
            case RecommendationStatus.accepted.stringValue:
                text += " ✅"
            case RecommendationStatus.dismissed.stringValue:
                text += " ❌"
            case RecommendationStatus.snoozed.stringValue:
                text += " 😴"
            case RecommendationStatus.expired.stringValue:
                text += " ⏰"
            case RecommendationStatus.modified.stringValue:
                text += " ✏️"
            default:
                text += " ⏳"
            }
        }
        
        cell.textLabel?.text = text
        
        // Detail text
        var details: [String] = []
        
        if recommendation.glucoseAtTime > 0 {
            details.append(String(format: "BG: %.0f", recommendation.glucoseAtTime))
        }
        
        if recommendation.iobAtTime > 0 {
            details.append(String(format: "IOB: %.1f", recommendation.iobAtTime))
        }
        
        if recommendation.cobAtTime > 0 {
            details.append(String(format: "COB: %.0f", recommendation.cobAtTime))
        }
        
        if let trend = recommendation.trendArrow {
            details.append(trend)
        }
        
        cell.detailTextLabel?.text = details.joined(separator: " • ")
        
        // Color coding based on urgency
        switch recommendation.urgencyLevel {
        case 3: // critical
            cell.textLabel?.textColor = .systemRed
        case 2: // high
            cell.textLabel?.textColor = .systemOrange
        case 1: // medium
            cell.textLabel?.textColor = .label
        default: // low
            cell.textLabel?.textColor = .secondaryLabel
        }
    }
    
    private func getSectionDate(for section: Int) -> String {
        let dates = Array(Set<String>(recommendations.compactMap { recommendation in
            guard let timestamp = recommendation.timestamp else { return nil }
            return dateFormatter.string(from: timestamp)
        }).sorted().reversed())
        
        return dates[section]
    }
    
    private func getRecommendation(for indexPath: IndexPath) -> MDIRecommendationHistory {
        let sectionDate = getSectionDate(for: indexPath.section)
        let sectionRecommendations = recommendations.filter { recommendation in
            guard let timestamp = recommendation.timestamp else { return false }
            return dateFormatter.string(from: timestamp) == sectionDate
        }
        return sectionRecommendations[indexPath.row]
    }
}

// MARK: - UITableViewDelegate

extension MDIHistoryViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let recommendation = getRecommendation(for: indexPath)
        showRecommendationDetail(recommendation)
    }
    
    private func showRecommendationDetail(_ recommendation: MDIRecommendationHistory) {
        var message = ""
        
        if let reason = recommendation.reason {
            message += reason + "\n\n"
        }
        
        message += "Recommended: " + recommendation.displayDescription + "\n"
        
        if recommendation.status == RecommendationStatus.modified.stringValue {
            message += "Actual: "
            if recommendation.actualDoseTaken > 0 {
                message += String(format: "%.1fU", recommendation.actualDoseTaken)
            }
            if recommendation.actualCarbsTaken > 0 {
                message += String(format: " %.0fg", recommendation.actualCarbsTaken)
            }
            message += "\n"
        }
        
        message += "\nGlucose: " + String(format: "%.0f mg/dL", recommendation.glucoseAtTime)
        if recommendation.predictedGlucose > 0 {
            message += " → " + String(format: "%.0f", recommendation.predictedGlucose)
        }
        
        message += "\nIOB: " + String(format: "%.1fU", recommendation.iobAtTime)
        message += "\nCOB: " + String(format: "%.0fg", recommendation.cobAtTime)
        
        if let notes = recommendation.notes, !notes.isEmpty {
            message += "\n\nNotes: " + notes
        }
        
        let alert = UIAlertController(
            title: "Recommendation Details",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(alert, animated: true)
    }
}