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

        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 380)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: MenuBarView(viewModel: viewModel))

        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

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
        guard let button = statusItem.button else { return }

        let icon = viewModel.timerState.menuBarIcon
        let title = viewModel.menuBarTitle

        if title.isEmpty {
            button.image = NSImage(systemSymbolName: icon, accessibilityDescription: "Pomodoro")
            button.title = ""
        } else {
            button.image = NSImage(systemSymbolName: icon, accessibilityDescription: "Pomodoro")
            button.title = " \(title)"
            button.imagePosition = .imageLeading
        }
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
            menu.addItem(withTitle: "Reset", action: #selector(resetTimer), keyEquivalent: "")
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Pomodoro", action: #selector(quitApp), keyEquivalent: "q")

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func startWork() {
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

    @objc private func resetTimer() {
        viewModel.reset()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
