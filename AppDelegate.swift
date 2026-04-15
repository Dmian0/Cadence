import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let vm = SessionViewModel()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        bindMenubarUpdates()

        // Hide from Dock — this is a menubar-only app
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "25:00"
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Cadence")
            button.imagePosition = .imageLeft
            button.target = self
            button.action = #selector(handleStatusButtonClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleStatusButtonClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
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
        menu.addItem(NSMenuItem(title: "Cadence", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil  // reset so left click works next time
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(vm: vm)
        )
    }

    // MARK: - Menubar label binding

    private func bindMenubarUpdates() {
        // Update menubar label every second the timer is running
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMenubarLabel()
            }
            .store(in: &cancellables)
    }

    private func updateMenubarLabel() {
        guard let button = statusItem.button else { return }
        button.title = " \(vm.timer.displayString)"

        // Dot icon color reflects current mode
        if let img = NSImage(systemSymbolName: vm.currentMode.sfSymbol,
                             accessibilityDescription: vm.currentMode.label) {
            let colored = img.withSymbolConfiguration(
                NSImage.SymbolConfiguration(paletteColors: [
                    NSColor(vm.currentMode.color)
                ])
            ) ?? img
            button.image = colored
        }
    }
}
