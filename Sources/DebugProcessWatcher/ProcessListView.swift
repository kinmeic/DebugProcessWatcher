import AppKit
import SwiftUI

struct ProcessListView: View {
    private static let allLanguagesLabel = "All"
    private static let preferredLanguageOptions = [
        "Java",
        "Node.js",
        "Python",
        "Go (Toolchain)",
        "Go (Module)",
        "Rust (Cargo)",
        "Rust (Binary)",
        "Swift",
        "Ruby",
        "PHP",
        ".NET",
        "Deno",
        "Bun"
    ]

    @StateObject var monitor = ProcessMonitor.shared
    @State private var searchText = ""
    @State private var languageFilter = Self.allLanguagesLabel
    @State private var selected: Set<ProcessInfo.ID> = []

    var languageOptions: [String] {
        let detected = Set(monitor.processes.map(\.language))
        let preferred = Self.preferredLanguageOptions.filter { detected.contains($0) }
        let extras = detected.subtracting(Self.preferredLanguageOptions).sorted()
        return [Self.allLanguagesLabel] + preferred + extras
    }

    var visibleSelectedCount: Int {
        filtered.filter { selected.contains($0.id) }.count
    }

    var filtered: [ProcessInfo] {
        let languageScoped = monitor.processes.filter {
            languageFilter == Self.allLanguagesLabel || $0.language == languageFilter
        }

        if searchText.isEmpty { return languageScoped }
        let lower = searchText.lowercased()
        return languageScoped.filter {
            $0.name.lowercased().contains(lower) ||
            $0.command.lowercased().contains(lower) ||
            $0.language.lowercased().contains(lower) ||
            $0.cwd.lowercased().contains(lower) ||
            $0.cpu.lowercased().contains(lower) ||
            $0.mem.lowercased().contains(lower) ||
            "\($0.port)".contains(lower) ||
            "\($0.pid)".contains(lower)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                if monitor.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 20, height: 20)
                }
                Button(action: { confirmBatchKill() }) {
                    Image(systemName: "xmark.bin")
                }
                .tint(.red)
                .help("Kill selected processes")
                .disabled(monitor.isLoading || visibleSelectedCount == 0)

                Button(action: { monitor.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(monitor.isLoading)
            }
            .padding()

            HStack(spacing: 0) {
                languageSidebar
                Divider()
                mainContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack(alignment: .center, spacing: 12) {
                Label("\(filtered.count) processes", systemImage: "waveform.path.ecg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if languageFilter != Self.allLanguagesLabel {
                    Text(languageFilter)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary.opacity(0.6), in: Capsule())
                }
                Spacer()
                Toggle("Auto Refresh", isOn: $monitor.autoRefresh)
                    .toggleStyle(.switch)
                    .font(.caption)
                    .controlSize(.small)
                    .labelsHidden()
                Text("Auto Refresh")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 36, alignment: .center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .frame(minWidth: 800, minHeight: 400)
        .onAppear {
            monitor.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshProcesses)) { _ in
            monitor.refresh()
        }
        .onChange(of: monitor.processes.map(\.language).sorted()) {
            if !languageOptions.contains(languageFilter) {
                languageFilter = Self.allLanguagesLabel
            }
        }
    }

    private var languageSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Languages")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(languageOptions, id: \.self) { option in
                        Button {
                            languageFilter = option
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: option == Self.allLanguagesLabel ? "square.grid.2x2" : "chevron.left.forwardslash.chevron.right")
                                    .foregroundStyle(option == languageFilter ? .primary : .secondary)
                                Text(option)
                                    .lineLimit(1)
                                Spacer()
                                if option == languageFilter {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .background(option == languageFilter ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 190, alignment: .topLeading)
        .background(.quaternary.opacity(0.18))
    }

    private var mainContent: some View {
        Group {
            if monitor.isLoading && monitor.processes.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Scanning processes...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "network")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(languageFilter == Self.allLanguagesLabel ? "No debug processes found" : "No \(languageFilter) processes found")
                        .font(.title2)
                    Text(languageFilter == Self.allLanguagesLabel ? "No development services are currently listening on any ports." : "No development services matching the current language filter are listening on any ports.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(of: ProcessInfo.self, selection: $selected) {
                    TableColumn("Action") { proc in
                        HStack(spacing: 6) {
                            Button {
                                confirmKill(proc)
                            } label: {
                                Image(systemName: "xmark.bin")
                            }
                            .tint(.red)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Kill process")

                            Button {
                                openTerminal(at: proc.cwd)
                            } label: {
                                Image(systemName: "terminal")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Open Terminal at CWD")
                            .disabled(proc.cwd == "-")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .width(min: 88, ideal: 100)

                    TableColumn("Port") { proc in
                        Text(verbatim: String(proc.port))
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 50, ideal: 70)

                    TableColumn("CPU %") { proc in
                        Text(proc.cpu)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 50, ideal: 70)

                    TableColumn("MEM %") { proc in
                        Text(proc.mem)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 50, ideal: 70)

                    TableColumn("Language") { proc in
                        Text(proc.language)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 80, ideal: 120)

                    TableColumn("PID") { proc in
                        Text(verbatim: String(proc.pid))
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 60, ideal: 80)

                    TableColumn("Proto") { proc in
                        Text(proc.proto)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 40, ideal: 60)

                    TableColumn("Address") { proc in
                        Text(proc.address)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("Command") { proc in
                        Text(proc.command)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .help(proc.command)
                            .contextMenu {
                                Button("Copy Command") {
                                    copyToPasteboard(proc.command)
                                }
                            }
                    }
                    .width(min: 200, ideal: 400)

                    TableColumn("CWD") { proc in
                        Text(proc.cwd)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .help(proc.cwd)
                            .contextMenu {
                                Button("Copy CWD") {
                                    copyToPasteboard(proc.cwd)
                                }
                            }
                    }
                    .width(min: 150, ideal: 250)
                } rows: {
                    ForEach(filtered) { proc in
                        TableRow(proc)
                    }
                }
            }
        }
    }

    private func confirmKill(_ proc: ProcessInfo) {
        let alert = NSAlert()
        alert.messageText = "Terminate Process?"
        alert.informativeText = "Are you sure you want to kill \(proc.name) (PID: \(proc.pid))?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Kill")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            monitor.kill(pid: proc.pid)
        }
    }

    private func confirmBatchKill() {
        let selectedProcs = filtered.filter { selected.contains($0.id) }
        let uniquePIDs = Set(selectedProcs.map { $0.pid })
        guard !uniquePIDs.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Terminate \(uniquePIDs.count) Selected Process(es)?"
        alert.informativeText = "This will kill \(uniquePIDs.count) selected process(es). Are you sure?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Kill All")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            monitor.kill(pids: Array(uniquePIDs))
            selected.removeAll()
        }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func openTerminal(at cwd: String) {
        guard cwd != "-" else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Terminal", cwd]

        do {
            try task.run()
        } catch {
            NSLog("[DPW] Failed to open Terminal at \(cwd): \(error.localizedDescription)")
        }
    }
}
