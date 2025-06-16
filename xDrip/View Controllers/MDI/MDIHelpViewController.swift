import UIKit

/// View controller to display MDI Loop help and documentation
class MDIHelpViewController: UIViewController {
    
    // MARK: - Properties
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var helpTextView: UITextView!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "MDI Loop Help"
        setupUI()
        loadHelpContent()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissHelp)
        )
        
        // Configure text view
        helpTextView.isEditable = false
        helpTextView.isSelectable = true
        helpTextView.dataDetectorTypes = .link
    }
    
    private func loadHelpContent() {
        let helpText = """
        # MDI Loop Emulation
        
        The MDI Loop feature provides intelligent insulin dosing recommendations for Multiple Daily Injection (MDI) users based on advanced prediction algorithms.
        
        ## How It Works
        
        The MDI Loop continuously monitors your glucose levels and analyzes trends to provide timely recommendations for:
        
        • **Correction Boluses** - When your blood glucose is trending high
        • **Meal Boluses** - Based on carbohydrate intake
        • **Low Prevention** - Alerts when trending toward hypoglycemia
        
        ## Key Features
        
        ### Smart Predictions
        Using the same algorithms as automated insulin delivery systems, MDI Loop predicts your glucose levels up to 4 hours into the future based on:
        - Current glucose levels and trends
        - Insulin on board (IOB)
        - Carbohydrates on board (COB)
        - Your personal insulin sensitivity settings
        
        ### Safety First
        Every recommendation includes multiple safety checks:
        - Maximum dose limits
        - Minimum time between corrections
        - IOB stacking prevention
        - Validation of all calculations
        
        ### Customizable Settings
        Tailor the system to your needs:
        - Insulin sensitivity factor (ISF)
        - Carbohydrate ratio (I:C)
        - Daily basal insulin amount
        - Safety limits and thresholds
        - Notification preferences
        
        ## Getting Started
        
        1. **Configure Your Settings**
           - Go to Settings > MDI Loop
           - Enter your insulin sensitivity factor
           - Set your carb ratio
           - Input your daily basal insulin
        
        2. **Enable MDI Loop**
           - Toggle "Enable MDI Loop" in settings
           - Allow notifications when prompted
        
        3. **Review Recommendations**
           - You'll receive notifications for dosing suggestions
           - Tap to view details including reasoning
           - Accept, snooze, or dismiss as appropriate
        
        ## Understanding Recommendations
        
        Each recommendation includes:
        - **Type**: Correction, meal, or combined bolus
        - **Amount**: Suggested insulin units
        - **Reason**: Why this is recommended
        - **Predictions**: Expected glucose outcomes
        
        ### Urgency Levels
        
        🔴 **Critical** - Immediate action recommended
        🟡 **High** - Action recommended soon
        🟢 **Normal** - Standard recommendation
        ⚪ **Low** - Optional adjustment
        
        ## Important Notes
        
        ⚠️ **Medical Disclaimer**: This feature provides suggestions only. Always use your clinical judgment and consult with your healthcare provider about insulin dosing decisions.
        
        ⚠️ **Not a Replacement**: MDI Loop does not replace the need for glucose monitoring, carb counting, or medical care.
        
        ## Troubleshooting
        
        **No Recommendations?**
        - Check that MDI Loop is enabled
        - Ensure you have recent glucose readings
        - Verify your settings are configured
        - Check notification permissions
        
        **Too Many Notifications?**
        - Adjust the minimum time between recommendations
        - Configure quiet hours in notification settings
        - Fine-tune your correction thresholds
        
        **Predictions Seem Off?**
        - Verify your insulin sensitivity factor
        - Check your carb ratio settings
        - Ensure basal insulin is set correctly
        - Consider factors like exercise, illness, or stress
        
        ## Support
        
        For additional help or to report issues:
        - Check the xDrip4iOS documentation
        - Visit the support forums
        - Contact your healthcare provider for medical questions
        
        ---
        
        Version 1.0 | © 2024 xDrip4iOS Team
        """
        
        // Convert markdown-style text to attributed string
        let attributedText = NSMutableAttributedString(string: helpText)
        
        // Apply styling
        let fullRange = NSRange(location: 0, length: attributedText.length)
        attributedText.addAttribute(.font, value: UIFont.systemFont(ofSize: 16), range: fullRange)
        
        // Style headers
        styleHeaders(in: attributedText)
        
        // Style bullet points
        styleBulletPoints(in: attributedText)
        
        // Style warnings
        styleWarnings(in: attributedText)
        
        helpTextView.attributedText = attributedText
    }
    
    // MARK: - Styling Helpers
    
    private func styleHeaders(in attributedText: NSMutableAttributedString) {
        let text = attributedText.string
        
        // Style # headers
        let h1Pattern = try! NSRegularExpression(pattern: "^# (.+)$", options: .anchorsMatchLines)
        let h2Pattern = try! NSRegularExpression(pattern: "^## (.+)$", options: .anchorsMatchLines)
        let h3Pattern = try! NSRegularExpression(pattern: "^### (.+)$", options: .anchorsMatchLines)
        
        let fullRange = NSRange(location: 0, length: text.count)
        
        // H1
        h1Pattern.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let range = match?.range else { return }
            attributedText.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 24), range: range)
        }
        
        // H2
        h2Pattern.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let range = match?.range else { return }
            attributedText.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 20), range: range)
        }
        
        // H3
        h3Pattern.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let range = match?.range else { return }
            attributedText.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 18), range: range)
        }
    }
    
    private func styleBulletPoints(in attributedText: NSMutableAttributedString) {
        let text = attributedText.string
        let bulletPattern = try! NSRegularExpression(pattern: "^• (.+)$", options: .anchorsMatchLines)
        let fullRange = NSRange(location: 0, length: text.count)
        
        bulletPattern.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let range = match?.range else { return }
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = 0
            paragraphStyle.headIndent = 20
            attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        }
    }
    
    private func styleWarnings(in attributedText: NSMutableAttributedString) {
        let text = attributedText.string
        let warningPattern = try! NSRegularExpression(pattern: "⚠️ (.+)", options: [])
        let fullRange = NSRange(location: 0, length: text.count)
        
        warningPattern.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let range = match?.range else { return }
            attributedText.addAttribute(.foregroundColor, value: UIColor.systemOrange, range: range)
            attributedText.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 16), range: range)
        }
    }
    
    // MARK: - Actions
    
    @objc private func dismissHelp() {
        dismiss(animated: true)
    }
}