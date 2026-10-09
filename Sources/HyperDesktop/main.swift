import AppKit
import SwiftUI
import WebKit

private let hyperURL = URL(string: "http://127.0.0.1:3010")!
private let launchAgentLabel =
    Bundle.main.object(forInfoDictionaryKey: "HyperLaunchAgentLabel") as? String
    ?? "com.hypercode.server"
private let launchAgent = "gui/\(getuid())/\(launchAgentLabel)"

@main
@MainActor
struct HyperDesktopApp: App {
    @StateObject private var tabs = HyperTabStore()

    var body: some Scene {
        WindowGroup {
            HyperWindow()
                .environmentObject(tabs)
        }
        .defaultSize(width: 1320, height: 860)
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("Вкладки") {
                Button("Новая вкладка") { tabs.newTab() }
                Button("Закрыть вкладку") { tabs.closeSelected() }
                Divider()
                Button("Перейти к вкладке 1") { tabs.select(index: 0) }
                Button("Перейти к вкладке 2") { tabs.select(index: 1) }
            }
        }
    }
}

@MainActor
private final class HyperTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate {
    let id = UUID()
    let webView = WKWebView()
    @Published private(set) var title = "Hyper"

    override init() {
        super.init()
        webView.navigationDelegate = self
    }

    func loadIfNeeded() {
        guard webView.url == nil else { return }
        webView.load(URLRequest(url: hyperURL))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        title = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? "Hyper"
    }
}

@MainActor
private final class HyperTabStore: ObservableObject {
    @Published private(set) var tabs: [HyperTab] = []
    @Published private(set) var selectedID: UUID?
    private var serverReady = false

    init() {
        newTab()
    }

    var selectedTab: HyperTab? {
        tabs.first(where: { $0.id == selectedID })
    }

    func markServerReady() {
        serverReady = true
        tabs.forEach { $0.loadIfNeeded() }
    }

    func newTab() {
        let tab = HyperTab()
        tabs.append(tab)
        selectedID = tab.id
        if serverReady { tab.loadIfNeeded() }
    }

    func select(index: Int) {
        guard tabs.indices.contains(index) else { return }
        selectedID = tabs[index].id
        if serverReady { tabs[index].loadIfNeeded() }
    }

    func select(_ tab: HyperTab) {
        selectedID = tab.id
        if serverReady { tab.loadIfNeeded() }
    }

    func closeSelected() {
        guard let selectedID, let index = tabs.firstIndex(where: { $0.id == selectedID }) else { return }
        tabs.remove(at: index)
        if tabs.isEmpty {
            NSApp.keyWindow?.close()
        } else {
            self.selectedID = tabs[min(index, tabs.count - 1)].id
        }
    }

    func close(_ tab: HyperTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        let wasSelected = selectedID == tab.id
        tabs.remove(at: index)
        guard !tabs.isEmpty else {
            NSApp.keyWindow?.close()
            return
        }
        if wasSelected { selectedID = tabs[min(index, tabs.count - 1)].id }
    }
}

private struct HyperWindow: View {
    @EnvironmentObject private var tabs: HyperTabStore
    @State private var ready = false
    @State private var message = "Проверяю локальный сервис…"
    @State private var attempt = 0
    @State private var keyMonitor: Any?

    var body: some View {
        Group {
            if ready {
                BrowserTabsView()
            } else {
                StartupView(message: message, retry: { attempt += 1 })
            }
        }
        .task(id: attempt) { await connect() }
        .onAppear(perform: installKeyMonitor)
        .onDisappear(perform: removeKeyMonitor)
        .frame(minWidth: 900, minHeight: 620)
    }

    @MainActor
    private func connect() async {
        ready = false
        message = "Проверяю локальный сервис…"
        if await isHealthy() {
            markReady()
            return
        }

        message = "Запускаю Hyper через launchd…"
        do {
            try kickstartLaunchAgent()
        } catch {
            message = "Не удалось запустить сервис Hyper. Проверьте установку LaunchAgent."
            return
        }

        for _ in 0..<40 {
            try? await Task.sleep(for: .milliseconds(750))
            if await isHealthy() {
                markReady()
                return
            }
        }
        message = "Не удалось дождаться Hyper на http://127.0.0.1:3010. Проверьте ./start.sh и внешний PostgreSQL."
    }

    @MainActor
    private func markReady() {
        ready = true
        tabs.markServerReady()
    }

    private func isHealthy() async -> Bool {
        var request = URLRequest(url: hyperURL)
        request.timeoutInterval = 2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else { return false }
            return response.statusCode < 500
        } catch {
            return false
        }
    }

    private func kickstartLaunchAgent() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["kickstart", launchAgent]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw LaunchError.agentUnavailable }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers == .command, let key = event.charactersIgnoringModifiers?.lowercased() else {
                return event
            }
            switch key {
            case "t":
                Task { @MainActor in tabs.newTab() }
                return nil
            case "w":
                Task { @MainActor in tabs.closeSelected() }
                return nil
            case "1":
                Task { @MainActor in tabs.select(index: 0) }
                return nil
            case "2":
                Task { @MainActor in tabs.select(index: 1) }
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private enum LaunchError: Error { case agentUnavailable }
}

private struct BrowserTabsView: View {
    @EnvironmentObject private var tabs: HyperTabStore

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 5) {
                    ForEach(tabs.tabs) { tab in
                        TabButton(
                            tab: tab,
                            selected: tabs.selectedID == tab.id,
                            select: { tabs.select(tab) },
                            close: { tabs.close(tab) }
                        )
                    }
                    Button(action: { tabs.newTab() }) {
                        Image(systemName: "plus")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .help("Новая вкладка (⌘T)")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }
            .scrollIndicators(.hidden)

            Divider()
            if let tab = tabs.selectedTab {
                TabWebView(tab: tab)
            }
        }
    }
}

private struct TabButton: View {
    @ObservedObject var tab: HyperTab
    let selected: Bool
    let select: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: select) {
                Text(tab.title)
                    .lineLimit(1)
                    .frame(maxWidth: 180, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Закрыть вкладку")
        }
        .padding(.leading, 11)
        .padding(.trailing, 5)
        .padding(.vertical, 5)
        .background(selected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(perform: select)
    }
}

private struct TabWebView: NSViewRepresentable {
    @ObservedObject var tab: HyperTab

    func makeNSView(context: Context) -> WKWebView {
        tab.loadIfNeeded()
        return tab.webView
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        tab.loadIfNeeded()
    }
}

private struct StartupView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            if message.hasPrefix("Не удалось") {
                Button("Повторить", action: retry)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
