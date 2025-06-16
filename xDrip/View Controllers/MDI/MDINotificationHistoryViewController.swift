import UIKit
import UserNotifications

/// View controller to display notification history for MDI recommendations
class MDINotificationHistoryViewController: UIViewController {
    
    // MARK: - Properties
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyStateLabel: UILabel!
    
    private var notificationHistory: [NotificationHistoryItem] = []
    private let dateFormatter = DateFormatter()
    private let timeFormatter = DateFormatter()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Notification History"
        setupFormatters()
        setupUI()
        loadNotificationHistory()
    }
    
    // MARK: - Setup
    
    private func setupFormatters() {
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
    }
    
    private func setupUI() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        
        // Add refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        // Configure empty state
        emptyStateLabel.text = "No notifications have been sent yet.\n\nWhen MDI Loop sends recommendations,\nthey will appear here."
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.textColor = .secondaryLabel
    }
    
    // MARK: - Data Loading
    
    private func loadNotificationHistory() {
        // Get delivered notifications
        UNUserNotificationCenter.current().getDeliveredNotifications { [weak self] notifications in
            guard let self = self else { return }
            
            // Filter MDI notifications
            let mdiNotifications = notifications.filter { 
                $0.request.content.categoryIdentifier == "MDI_RECOMMENDATION" 
            }
            
            // Convert to history items
            self.notificationHistory = mdiNotifications.map { notification in
                NotificationHistoryItem(from: notification)
            }.sorted { $0.date > $1.date }
            
            DispatchQueue.main.async {
                self.updateUI()
            }
        }
        
        // Also get pending notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }
            
            // Filter MDI notifications
            let mdiRequests = requests.filter { 
                $0.content.categoryIdentifier == "MDI_RECOMMENDATION" 
            }
            
            // Add pending notifications to history
            let pendingItems = mdiRequests.map { request in
                NotificationHistoryItem(from: request, isPending: true)
            }
            
            DispatchQueue.main.async {
                self.notificationHistory.append(contentsOf: pendingItems)
                self.notificationHistory.sort { $0.date > $1.date }
                self.updateUI()
            }
        }
    }
    
    private func updateUI() {
        emptyStateLabel.isHidden = !notificationHistory.isEmpty
        tableView.isHidden = notificationHistory.isEmpty
        tableView.reloadData()
        tableView.refreshControl?.endRefreshing()
    }
    
    // MARK: - Actions
    
    @objc private func refreshData() {
        loadNotificationHistory()
    }
    
    @IBAction func clearHistoryTapped(_ sender: Any) {
        let alert = UIAlertController(
            title: "Clear History",
            message: "This will remove all delivered MDI notifications. Are you sure?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.clearHistory()
        })
        
        present(alert, animated: true)
    }
    
    private func clearHistory() {
        // Get all delivered MDI notifications
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let mdiIdentifiers = notifications
                .filter { $0.request.content.categoryIdentifier == "MDI_RECOMMENDATION" }
                .map { $0.request.identifier }
            
            // Remove them
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: mdiIdentifiers)
            
            DispatchQueue.main.async { [weak self] in
                self?.loadNotificationHistory()
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension MDINotificationHistoryViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // Group by date
        let dates = Set(notificationHistory.map { item in
            dateFormatter.string(from: item.date)
        })
        return dates.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionDate = getSectionDate(for: section)
        return notificationHistory.filter { item in
            dateFormatter.string(from: item.date) == sectionDate
        }.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return getSectionDate(for: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell") ?? 
                   UITableViewCell(style: .subtitle, reuseIdentifier: "NotificationCell")
        
        let item = getItem(for: indexPath)
        
        // Configure cell
        configureCell(cell, with: item)
        
        return cell
    }
    
    private func configureCell(_ cell: UITableViewCell, with item: NotificationHistoryItem) {
        // Time and title
        let time = timeFormatter.string(from: item.date)
        cell.textLabel?.text = "\(time) - \(item.title)"
        
        // Body text
        cell.detailTextLabel?.text = item.body
        cell.detailTextLabel?.numberOfLines = 2
        
        // Status indicator
        if item.isPending {
            cell.textLabel?.text = "⏳ " + (cell.textLabel?.text ?? "")
            cell.textLabel?.textColor = .systemOrange
        } else {
            cell.textLabel?.textColor = .label
        }
        
        // Urgency color
        switch item.urgency {
        case "3": // critical
            cell.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        case "2": // high
            cell.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
        default:
            cell.backgroundColor = nil
        }
    }
    
    private func getSectionDate(for section: Int) -> String {
        let dates = Set(notificationHistory.map { item in
            dateFormatter.string(from: item.date)
        }).sorted().reversed()
        
        return Array(dates)[section]
    }
    
    private func getItem(for indexPath: IndexPath) -> NotificationHistoryItem {
        let sectionDate = getSectionDate(for: indexPath.section)
        let sectionItems = notificationHistory.filter { item in
            dateFormatter.string(from: item.date) == sectionDate
        }
        return sectionItems[indexPath.row]
    }
}

// MARK: - UITableViewDelegate

extension MDINotificationHistoryViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let item = getItem(for: indexPath)
        showNotificationDetail(item)
    }
    
    private func showNotificationDetail(_ item: NotificationHistoryItem) {
        let alert = UIAlertController(
            title: item.title,
            message: item.body + "\n\nSent: " + DateFormatter.localizedString(from: item.date, dateStyle: .medium, timeStyle: .short),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(alert, animated: true)
    }
}

// MARK: - NotificationHistoryItem

struct NotificationHistoryItem {
    let identifier: String
    let title: String
    let body: String
    let date: Date
    let urgency: String
    let isPending: Bool
    
    init(from notification: UNNotification) {
        self.identifier = notification.request.identifier
        self.title = notification.request.content.title
        self.body = notification.request.content.body
        self.date = notification.date
        self.urgency = notification.request.content.userInfo["urgency"] as? String ?? "1"
        self.isPending = false
    }
    
    init(from request: UNNotificationRequest, isPending: Bool) {
        self.identifier = request.identifier
        self.title = request.content.title
        self.body = request.content.body
        self.date = (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() ?? Date()
        self.urgency = request.content.userInfo["urgency"] as? String ?? "1"
        self.isPending = isPending
    }
}