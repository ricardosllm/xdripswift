//
//  Libre2HandoverViewController.swift
//  xdrip
//
//  Created for xDrip4iOS
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import UIKit

/// View controller for showing Libre 2 to Watch handover progress
class Libre2HandoverViewController: UIViewController {
    
    // MARK: - Properties
    
    /// Progress view to show handover stages
    private let progressView = UIProgressView(progressViewStyle: .bar)
    
    /// Activity indicator
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    
    /// Status label
    private let statusLabel = UILabel()
    
    /// Countdown label for BLE window
    private let countdownLabel = UILabel()
    
    /// Instructions label
    private let instructionsLabel = UILabel()
    
    /// Stack view for layout
    private let stackView = UIStackView()
    
    /// Timer for countdown
    private var countdownTimer: Timer?
    
    /// BLE activation expiry time
    private var bleExpiryTime: Date?
    
    /// Current stage of handover
    private var currentStage: HandoverStage = .disconnecting {
        didSet {
            updateUI()
        }
    }
    
    /// Handover stages
    enum HandoverStage {
        case disconnecting
        case waitingForNFC
        case nfcScanning
        case sendingSensorData
        case bleActivated
        case watchConnecting
        case completed
        case failed(String)
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupNotifications()
        startHandover()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        countdownTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Watch Handover"
        
        // Configure navigation
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        // Configure status label
        statusLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        
        // Configure countdown label
        countdownLabel.font = .monospacedDigitSystemFont(ofSize: 24, weight: .bold)
        countdownLabel.textAlignment = .center
        countdownLabel.textColor = .systemBlue
        countdownLabel.isHidden = true
        
        // Configure instructions label
        instructionsLabel.font = .systemFont(ofSize: 16)
        instructionsLabel.textAlignment = .center
        instructionsLabel.numberOfLines = 0
        instructionsLabel.textColor = .secondaryLabel
        
        // Configure progress view
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = .systemGray5
        
        // Configure stack view
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        stackView.addArrangedSubview(progressView)
        stackView.addArrangedSubview(activityIndicator)
        stackView.addArrangedSubview(statusLabel)
        stackView.addArrangedSubview(countdownLabel)
        stackView.addArrangedSubview(instructionsLabel)
        
        view.addSubview(stackView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            progressView.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 4)
        ])
        
        activityIndicator.startAnimating()
    }
    
    private func setupNotifications() {
        // Listen for handover stage updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisconnectionComplete),
            name: .libre2iPhoneDisconnectedForHandover,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNFCScanStarted),
            name: .libre2NFCScanStarted,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNFCScanComplete),
            name: .libre2NFCScanCompleted,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSensorDataSharing),
            name: .libre2ShouldShareSensorDataWithWatch,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWatchConnectionUpdate),
            name: .libre2WatchConnectionUpdate,
            object: nil
        )
    }
    
    // MARK: - Actions
    
    private func startHandover() {
        currentStage = .disconnecting
        
        // Trigger the handover process
        guard let bluetoothPeripheralManager = UserDefaults.standard.bluetoothPeripheralManager else {
            currentStage = .failed("Bluetooth manager not available")
            return
        }
        
        bluetoothPeripheralManager.scanForLibre2ForWatchHandover()
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func updateCountdown() {
        guard let expiryTime = bleExpiryTime else { return }
        
        let remaining = expiryTime.timeIntervalSinceNow
        if remaining > 0 {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            countdownLabel.text = String(format: "BLE Window: %02d:%02d", minutes, seconds)
            
            // Change color based on time remaining
            if remaining < 60 {
                countdownLabel.textColor = .systemRed
            } else if remaining < 120 {
                countdownLabel.textColor = .systemOrange
            }
        } else {
            countdownLabel.text = "BLE Window Expired"
            countdownLabel.textColor = .systemRed
            countdownTimer?.invalidate()
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleDisconnectionComplete() {
        currentStage = .waitingForNFC
    }
    
    @objc private func handleNFCScanStarted() {
        currentStage = .nfcScanning
    }
    
    @objc private func handleSensorDataSharing() {
        currentStage = .sendingSensorData
    }
    
    @objc private func handleNFCScanComplete(_ notification: Notification) {
        // Check if scan was successful
        if let success = notification.userInfo?["success"] as? Bool, success {
            // Don't immediately jump to BLE activated, wait for sensor data stage
            // The sensor data will be sent first, then we'll show BLE activated
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.currentStage = .bleActivated
                
                // Start countdown timer (5 minutes)
                self?.bleExpiryTime = Date().addingTimeInterval(5 * 60)
                self?.countdownLabel.isHidden = false
                self?.countdownTimer = Timer.scheduledTimer(
                    timeInterval: 1.0,
                    target: self!,
                    selector: #selector(self?.updateCountdown),
                    userInfo: nil,
                    repeats: true
                )
            }
        } else {
            let error = notification.userInfo?["error"] as? String ?? "NFC scan failed"
            currentStage = .failed(error)
        }
    }
    
    @objc private func handleWatchConnectionUpdate(_ notification: Notification) {
        if let state = notification.userInfo?["state"] as? String {
            switch state {
            case "connecting":
                currentStage = .watchConnecting
            case "connected":
                currentStage = .completed
            case "failed":
                let error = notification.userInfo?["error"] as? String ?? "Watch connection failed"
                currentStage = .failed(error)
            default:
                break
            }
        }
    }
    
    // MARK: - UI Updates
    
    private func updateUI() {
        switch currentStage {
        case .disconnecting:
            progressView.setProgress(0.2, animated: true)
            statusLabel.text = "Disconnecting iPhone..."
            instructionsLabel.text = "Preparing for handover"
            
        case .waitingForNFC:
            progressView.setProgress(0.3, animated: true)
            statusLabel.text = "Ready for NFC Scan"
            instructionsLabel.text = "Hold your iPhone near the sensor"
            
        case .nfcScanning:
            progressView.setProgress(0.4, animated: true)
            statusLabel.text = "Scanning Sensor..."
            instructionsLabel.text = "Keep iPhone near sensor"
            
        case .sendingSensorData:
            progressView.setProgress(0.5, animated: true)
            statusLabel.text = "Sending Sensor Data to Watch..."
            instructionsLabel.text = "Transmitting security keys"
            
        case .bleActivated:
            progressView.setProgress(0.7, animated: true)
            statusLabel.text = "BLE Activated ✓"
            instructionsLabel.text = "Move Watch near sensor now"
            activityIndicator.stopAnimating()
            
        case .watchConnecting:
            progressView.setProgress(0.9, animated: true)
            statusLabel.text = "Watch Connecting..."
            instructionsLabel.text = "Keep Watch near sensor"
            activityIndicator.startAnimating()
            
        case .completed:
            progressView.setProgress(1.0, animated: true)
            statusLabel.text = "Handover Complete ✓"
            statusLabel.textColor = .systemGreen
            instructionsLabel.text = "Watch is now connected to sensor"
            activityIndicator.stopAnimating()
            countdownTimer?.invalidate()
            
            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.dismiss(animated: true)
            }
            
        case .failed(let error):
            progressView.setProgress(0, animated: true)
            statusLabel.text = "Handover Failed"
            statusLabel.textColor = .systemRed
            instructionsLabel.text = error
            activityIndicator.stopAnimating()
            countdownTimer?.invalidate()
            
            // Change cancel button to "Done"
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(cancelTapped)
            )
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let libre2iPhoneDisconnectedForHandover = Notification.Name("libre2iPhoneDisconnectedForHandover")
    static let libre2NFCScanStarted = Notification.Name("libre2NFCScanStarted")
    static let libre2NFCScanCompleted = Notification.Name("libre2NFCScanCompleted")
    static let libre2ShouldShareSensorDataWithWatch = Notification.Name("libre2ShouldShareSensorDataWithWatch")
    static let libre2WatchConnectionUpdate = Notification.Name("libre2WatchConnectionUpdate")
}