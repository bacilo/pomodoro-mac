import SwiftUI
import AppKit
import Combine

@main
struct PomodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
        }
        .windowResizability(.contentSize)
    }

    init() {
        // Skip activation policy during testing
        guard NSClassFromString("XCTestCase") == nil else { return }

        // Hide the main window and dock icon
        NSApp?.setActivationPolicy(.accessory)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var viewModel: PomodoroViewModel!
    var cancellables = Set<AnyCancellable>()
    var blinkTimer: Timer?
    var isBlinkOn: Bool = true

    // Marquee effect for slot name
    var marqueeTimer: Timer?
    var marqueeOffset: Int = 0
    var lastSlotName: String = ""
    let marqueeMaxChars = 10  // Max visible characters for slot name
    let marqueePadding = "   "  // Padding between repeated text

    // Timer suspension for popover display stability
    private var suspendedBlinkTimer: Bool = false
    private var suspendedMarqueeTimer: Bool = false

    private var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Skip UI setup during testing
        guard !isRunningTests else { return }

        // Hide any windows that were created
        for window in NSApp.windows {
            window.close()
        }

        viewModel = PomodoroViewModel()

        // Check for new day when app becomes active (e.g., after sleep or next day)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 500)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: MenuBarView(viewModel: viewModel))

        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: calculateMaxStatusItemWidth())

        if let button = statusItem.button {
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateStatusButton()
        }

        // Observe viewModel changes to update the button
        viewModel.$timerState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateStatusButton()
                }
            }
            .store(in: &cancellables)

        viewModel.$timeRemaining
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateStatusButton()
                }
            }
            .store(in: &cancellables)

        viewModel.$isRunning
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateStatusButton()
                }
            }
            .store(in: &cancellables)
    }

    private func updateStatusButton() {
        guard statusItem.button != nil else { return }

        let isVeryUrgent = viewModel.timerState == .work && viewModel.timeRemaining <= 15 // Last 15 seconds

        // Manage blink timer for very urgent state
        if isVeryUrgent && blinkTimer == nil {
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.isBlinkOn.toggle()
                    self?.updateStatusButtonAppearance()
                }
            }
        } else if !isVeryUrgent && blinkTimer != nil {
            blinkTimer?.invalidate()
            blinkTimer = nil
            isBlinkOn = true
        }

        // Manage marquee timer for slot name display
        let shouldShowSlotName = viewModel.settings.showSlotNameInMenuBar &&
                                 viewModel.timerState == .work &&
                                 viewModel.currentSlotName != nil
        let slotName = viewModel.currentSlotName ?? ""

        // Reset marquee offset if slot name changed
        if slotName != lastSlotName {
            lastSlotName = slotName
            marqueeOffset = 0
        }

        // Start/stop marquee timer based on whether we need to scroll
        let needsMarquee = shouldShowSlotName && slotName.count > marqueeMaxChars
        if needsMarquee && marqueeTimer == nil {
            marqueeTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    let fullText = self.lastSlotName + self.marqueePadding
                    self.marqueeOffset = (self.marqueeOffset + 1) % fullText.count
                    self.updateStatusButtonAppearance()
                }
            }
        } else if !needsMarquee && marqueeTimer != nil {
            marqueeTimer?.invalidate()
            marqueeTimer = nil
            marqueeOffset = 0
        }

        updateStatusButtonAppearance()
    }

    private func updateStatusButtonAppearance() {
        guard let button = statusItem.button else { return }

        let icon = viewModel.timerState.menuBarIcon
        let title = viewModel.menuBarTitle
        let isUrgent = viewModel.timerState == .work && viewModel.timeRemaining <= 120
        let isVeryUrgent = viewModel.timerState == .work && viewModel.timeRemaining <= 15

        // Use fully monospaced font for consistent width
        let monoFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        // Determine if we're showing slot name
        let showingSlotName = viewModel.settings.showSlotNameInMenuBar &&
                              viewModel.timerState == .work &&
                              viewModel.currentSlotName != nil

        if title.isEmpty {
            button.image = NSImage(systemSymbolName: icon, accessibilityDescription: "Pomodoro")
            button.attributedTitle = NSAttributedString(string: "")
        } else {
            button.image = NSImage(systemSymbolName: icon, accessibilityDescription: "Pomodoro")

            // Determine color based on urgency
            var textColor: NSColor = .labelColor
            if isVeryUrgent {
                textColor = isBlinkOn ? .systemRed : .labelColor
            } else if isUrgent {
                textColor = .systemRed
            }

            // Build the title string - use attributed string for different fonts
            let result = NSMutableAttributedString()

            // Timer portion with fully monospaced font
            let timerText = " \(title)"
            let timerAttributes: [NSAttributedString.Key: Any] = [
                .font: monoFont,
                .foregroundColor: textColor
            ]
            result.append(NSAttributedString(string: timerText, attributes: timerAttributes))

            // Add slot name if enabled and in work mode
            if showingSlotName,
               let slotName = viewModel.currentSlotName {

                var visibleSlotName: String
                if slotName.count <= marqueeMaxChars {
                    // Short name, pad to fixed width
                    visibleSlotName = slotName
                } else {
                    // Long name, apply marquee effect
                    let fullText = slotName + marqueePadding
                    let startIndex = fullText.index(fullText.startIndex, offsetBy: marqueeOffset % fullText.count)
                    var visiblePart = ""
                    var currentIndex = startIndex
                    for _ in 0..<marqueeMaxChars {
                        visiblePart.append(fullText[currentIndex])
                        currentIndex = fullText.index(after: currentIndex)
                        if currentIndex == fullText.endIndex {
                            currentIndex = fullText.startIndex
                        }
                    }
                    visibleSlotName = visiblePart
                }
                // Pad to fixed width to prevent jitter
                while visibleSlotName.count < marqueeMaxChars {
                    visibleSlotName += " "
                }

                // Slot name uses same monospaced font
                let slotAttributes: [NSAttributedString.Key: Any] = [
                    .font: monoFont,
                    .foregroundColor: textColor
                ]
                result.append(NSAttributedString(string: " · ", attributes: timerAttributes))
                result.append(NSAttributedString(string: visibleSlotName, attributes: slotAttributes))
            }

            button.attributedTitle = result
            button.imagePosition = .imageLeading
        }
    }

    private func calculateMaxStatusItemWidth() -> CGFloat {
        let monoFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        // Maximum: icon + " 00:00 · " + 10 chars slot name
        let maxContent = " 00:00 · " + String(repeating: "M", count: marqueeMaxChars)
        let textWidth = (maxContent as NSString).size(withAttributes: [.font: monoFont]).width
        let iconWidth: CGFloat = 20
        let padding: CGFloat = 8
        return iconWidth + textWidth + padding
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        if viewModel.timerState == .idle {
            menu.addItem(withTitle: "Start Focus", action: #selector(startWork), keyEquivalent: "")
        } else {
            if viewModel.isRunning {
                menu.addItem(withTitle: "Pause", action: #selector(pauseTimer), keyEquivalent: "")
            } else {
                menu.addItem(withTitle: "Resume", action: #selector(resumeTimer), keyEquivalent: "")
            }

            menu.addItem(NSMenuItem.separator())

            menu.addItem(withTitle: "Done (Complete Early)", action: #selector(completeEarly), keyEquivalent: "")
            menu.addItem(withTitle: "Skip", action: #selector(skipTimer), keyEquivalent: "")
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Pomodoro", action: #selector(quitApp), keyEquivalent: "q")

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func startWork() {
        // Check for unfilled placeholders first
        let placeholders = viewModel.slotManager.getTodayUnfilledPlaceholders()
        if !placeholders.isEmpty {
            // Open popover to prompt for placeholders
            togglePopover()
            return
        }
        viewModel.startWork()
    }

    @objc private func pauseTimer() {
        viewModel.pause()
    }

    @objc private func resumeTimer() {
        viewModel.resume()
    }

    @objc private func completeEarly() {
        viewModel.completeEarly()
    }

    @objc private func skipTimer() {
        viewModel.skip()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func applicationDidBecomeActive() {
        viewModel.slotManager.checkForNewDay()
    }

    // MARK: - NSPopoverDelegate

    func popoverDidShow(_ notification: Notification) {
        // Suspend timers to prevent jitter
        if blinkTimer != nil {
            suspendedBlinkTimer = true
            blinkTimer?.invalidate()
            blinkTimer = nil
        }
        if marqueeTimer != nil {
            suspendedMarqueeTimer = true
            marqueeTimer?.invalidate()
            marqueeTimer = nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        // Resume timers if they were suspended
        if suspendedBlinkTimer || suspendedMarqueeTimer {
            suspendedBlinkTimer = false
            suspendedMarqueeTimer = false
            updateStatusButton()  // Restart timers if still needed
        }
    }
}
