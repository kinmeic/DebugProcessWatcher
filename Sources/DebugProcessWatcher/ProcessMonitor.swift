import Foundation
import Combine

extension Notification.Name {
    static let refreshProcesses = Notification.Name("refreshProcesses")
}

@MainActor
final class ProcessMonitor: ObservableObject {
    static let shared = ProcessMonitor()
    @Published var processes: [ProcessInfo] = []
    @Published var isLoading = false
    @Published var autoRefresh = false {
        didSet {
            if autoRefresh {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }

    private var timer: Timer?

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        Task.detached(priority: .userInitiated) {
            let all = Self.fetchAll()
            let devOnly = all.filter { $0.language != "Other" }
            await MainActor.run {
                ProcessMonitor.shared.processes = devOnly
                ProcessMonitor.shared.isLoading = false
            }
        }
    }

    func kill(pid: Int, completion: (@Sendable () -> Void)? = nil) {
        Task.detached(priority: .userInitiated) {
            Self.sendKillSignal(to: pid)
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                ProcessMonitor.shared.refresh()
                completion?()
            }
        }
    }

    func kill(pids: [Int], completion: (@Sendable () -> Void)? = nil) {
        guard !pids.isEmpty else {
            completion?()
            return
        }
        Task.detached(priority: .userInitiated) {
            for pid in pids {
                Self.sendKillSignal(to: pid)
            }
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                ProcessMonitor.shared.refresh()
                completion?()
            }
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                ProcessMonitor.shared.refresh()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private nonisolated static func sendKillSignal(to pid: Int) {
        let task = Process()
        task.launchPath = "/bin/kill"
        task.arguments = ["-9", "\(pid)"]
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                NSLog("[DPW] kill -9 \(pid) failed with status \(task.terminationStatus)")
            }
        } catch {
            NSLog("[DPW] kill -9 \(pid) error: \(error)")
        }
    }

    private nonisolated static func fetchAll() -> [ProcessInfo] {
        let lsofItems = runLsof()
        guard !lsofItems.isEmpty else { return [] }

        let pids = Set(lsofItems.map { $0.pid })
        let psMap = runPS(pids: pids)
        let cwdMap = runCWD(pids: pids)

        return lsofItems.map { item in
            let ps = psMap[item.pid]
            let name = ps?.name ?? item.command
            let args = ps?.args ?? item.command
            let cpu = ps?.cpu ?? "-"
            let mem = ps?.mem ?? "-"
            let cwd = cwdMap[item.pid] ?? "-"
            let lang = detectLanguage(name: name, args: args, cwd: cwd)

            return ProcessInfo(
                pid: item.pid,
                name: name,
                command: args,
                address: item.address,
                port: item.port,
                proto: item.proto,
                language: lang,
                cwd: cwd,
                cpu: cpu,
                mem: mem
            )
        }
    }

    private struct LsofItem {
        let pid: Int
        let command: String
        let proto: String
        let address: String
        let port: Int
    }

    private struct PSInfo {
        let name: String
        let args: String
        let cpu: String
        let mem: String
    }

    private nonisolated static func runLsof() -> [LsofItem] {
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-iTCP", "-sTCP:LISTEN", "-P", "-n", "-F", "pPcn"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else {
                NSLog("[DPW] lsof exited with status \(task.terminationStatus)")
                return []
            }
        } catch {
            NSLog("[DPW] lsof failed: \(error)")
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else {
            NSLog("[DPW] lsof output decoding failed")
            return []
        }

        var results: [LsofItem] = []
        var currentPID: Int?
        var currentProto: String?
        var currentCommand: String?

        for line in text.components(separatedBy: .newlines) {
            guard !line.isEmpty else { continue }
            let prefix = line.prefix(1)
            let value = String(line.dropFirst())
            switch prefix {
            case "p":
                if let pid = currentPID, let proto = currentProto, let cmd = currentCommand {
                    let addrs = collectAddresses(text: text, after: line)
                    for (addr, port) in addrs {
                        results.append(LsofItem(pid: pid, command: cmd, proto: proto, address: addr, port: port))
                    }
                }
                currentPID = Int(value)
                currentProto = nil
                currentCommand = nil
            case "P":
                currentProto = value
            case "c":
                currentCommand = value
            default:
                break
            }
        }
        if let pid = currentPID, let proto = currentProto, let cmd = currentCommand {
            let addrs = collectAddresses(text: text)
            for (addr, port) in addrs {
                results.append(LsofItem(pid: pid, command: cmd, proto: proto, address: addr, port: port))
            }
        }
        return results
    }

    private nonisolated static func collectAddresses(text: String, after startLine: String? = nil) -> [(String, Int)] {
        var inBlock = startLine == nil
        var seen = Set<String>()
        var results: [(String, Int)] = []

        for line in text.components(separatedBy: .newlines) {
            if let start = startLine, line == start {
                inBlock = true
                continue
            }
            if !inBlock { continue }
            if line.hasPrefix("p") && line != startLine { break }
            if line.hasPrefix("n") {
                let val = String(line.dropFirst())
                if let parsed = parseAddress(val) {
                    let key = "\(parsed.0):\(parsed.1)"
                    if !seen.contains(key) {
                        seen.insert(key)
                        results.append(parsed)
                    }
                }
            }
        }
        return results
    }

    private nonisolated static func runPS(pids: Set<Int>) -> [Int: PSInfo] {
        guard !pids.isEmpty else { return [:] }
        let pidList = pids.sorted().map { "\($0)" }.joined(separator: ",")
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", pidList, "-o", "pid=,pcpu=,pmem=,args="]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else {
                NSLog("[DPW] ps exited with status \(task.terminationStatus)")
                return [:]
            }
        } catch {
            NSLog("[DPW] ps failed: \(error)")
            return [:]
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else {
            NSLog("[DPW] ps output decoding failed")
            return [:]
        }

        var results: [Int: PSInfo] = [:]
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 4, let pid = Int(parts[0]) else { continue }
            let cpu = String(parts[1])
            let mem = String(parts[2])
            let args = parts[3...].joined(separator: " ")
            let name = String(parts[3])
            results[pid] = PSInfo(name: name, args: args, cpu: cpu, mem: mem)
        }
        return results
    }

    private nonisolated static func runCWD(pids: Set<Int>) -> [Int: String] {
        guard !pids.isEmpty else { return [:] }
        let pidList = pids.sorted().map { "\($0)" }.joined(separator: ",")
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-p", pidList, "-a", "-d", "cwd", "-F", "pn"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else {
                NSLog("[DPW] lsof cwd exited with status \(task.terminationStatus)")
                return [:]
            }
        } catch {
            NSLog("[DPW] lsof cwd failed: \(error)")
            return [:]
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else {
            NSLog("[DPW] lsof cwd output decoding failed")
            return [:]
        }

        var results: [Int: String] = [:]
        var currentPID: Int?
        for line in text.components(separatedBy: .newlines) {
            guard !line.isEmpty else { continue }
            if line.hasPrefix("p") {
                currentPID = Int(line.dropFirst())
            } else if line.hasPrefix("n"), let pid = currentPID {
                results[pid] = String(line.dropFirst())
            }
        }
        return results
    }

    private nonisolated static func parseAddress(_ raw: String) -> (String, Int)? {
        var s = raw
        if let idx = s.firstIndex(of: "(") {
            s = String(s[..<idx]).trimmingCharacters(in: .whitespaces)
        }
        if s.hasPrefix("[") {
            guard let close = s.firstIndex(of: "]") else { return nil }
            let addr = String(s[s.startIndex...close])
            let rest = String(s[s.index(after: close)...])
            guard rest.hasPrefix(":") else { return nil }
            if let port = Int(rest.dropFirst()) {
                return (addr, port)
            }
        } else {
            let parts = s.split(separator: ":", maxSplits: 1)
            if parts.count == 2, let port = Int(parts[1]) {
                return (String(parts[0]), port)
            }
        }
        return nil
    }

    private nonisolated static func detectLanguage(name: String, args: String, cwd: String) -> String {
        let lower = name.lowercased()
        let argsLower = args.lowercased()
        let cwdLower = cwd.lowercased()
        let all = lower + " " + argsLower + " " + cwdLower
        let hasCargoManifest = projectHasMarker(named: "Cargo.toml", from: cwd)
        let hasGoModule = projectHasMarker(named: "go.mod", from: cwd)

        if all.contains("node") || all.contains("npm") || all.contains("npx") || all.contains("yarn") {
            return "Node.js"
        }
        if all.contains("python") || all.contains("pip") {
            return "Python"
        }
        if
            all.contains("java") ||
            all.contains("java -jar") ||
            all.contains(".jar") ||
            all.contains("spring-boot") ||
            all.contains("gradle") ||
            all.contains("gradlew") ||
            all.contains("mvn ") ||
            all.contains("mvnw")
        {
            return "Java"
        }
        if all.contains("ruby") || all.contains("gem") || all.contains("bundle") {
            return "Ruby"
        }
        if all.contains("php") {
            return "PHP"
        }
        if lower == "go" || all.contains("go run") || all.contains("go build") {
            return "Go (Toolchain)"
        }
        if all.contains("/go-build") || hasGoModule {
            return "Go (Module)"
        }
        if all.contains("swift") {
            return "Swift"
        }
        if all.contains("cargo") || all.contains("rustc") {
            return "Rust (Cargo)"
        }
        if all.contains("/target/debug/") || all.contains("/target/release/") || hasCargoManifest {
            return "Rust (Binary)"
        }
        if all.contains("dotnet") {
            return ".NET"
        }
        if all.contains("deno") {
            return "Deno"
        }
        if all.contains("bun") {
            return "Bun"
        }
        return "Other"
    }

    private nonisolated static func projectHasMarker(named marker: String, from cwd: String) -> Bool {
        guard cwd != "-", !cwd.isEmpty else { return false }

        let fileManager = FileManager.default
        var currentURL = URL(fileURLWithPath: cwd, isDirectory: true)
        let homePath = fileManager.homeDirectoryForCurrentUser.path

        for _ in 0..<6 {
            let markerPath = currentURL.appendingPathComponent(marker).path
            if fileManager.fileExists(atPath: markerPath) {
                return true
            }

            let parentURL = currentURL.deletingLastPathComponent()
            if parentURL.path == currentURL.path || parentURL.path.count < homePath.count {
                break
            }
            currentURL = parentURL
        }

        return false
    }
}
