import Foundation
import Darwin
import AppKit

// MARK: - Data Models

struct ProcessInfo: Identifiable {
    let id = UUID()
    let pid: Int32
    let name: String
    let memoryMB: Double
}

enum MemoryPressure: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

// MARK: - RAM Monitor

@Observable
final class RAMMonitor {

    // Published state
    var usedGB: Double = 0
    var totalGB: Double = 0
    var usagePercent: Int = 0
    var pressure: MemoryPressure = .low
    var topProcesses: [ProcessInfo] = []
    var swapUsedMB: Double = 0
    var cachedGB: Double = 0
    var chipName: String = "Apple Silicon"
    var lastError: String?

    private var timer: Timer?
    private let updateInterval: TimeInterval = 2.0

    // System-critical processes and prefixes — NEVER kill these
    private let systemCriticalNames: Set<String> = [
        "kernel_task", "launchd", "windowserver", "loginwindow",
        "systemuiserver", "dock", "finder", "cfprefsd",
        "distnoted", "notifyd", "opendirectoryd", "securityd",
        "coreservicesd", "coreauthd", "pboard", "mds",
        "mds_stores", "usereventsagent", "syslogd", "configd",
        "powerd", "airportd", "bluetoothd", "locationd",
        "trustd", "nsurlsessiond", "lsd", "timed",
        "iconservicesagent", "sharingd", "cloudd",
        "coreduetd", "callserviceshelper", "contextstored",
        "commerced", "mediaremoted", "rapportd", "symptomsd",
        "biomeagent", "corespeechd", "touchbaragent",
        "siriknowledged", "suggestd", "intelligenceplatformd",
        "spotlight", "corespotlightd", "searchpartyd",
        "fseventsd", "taskgated", "symptomsd",
        "sandboxd", "amfid", "keybagd", "accessoryd",
        "usernoted", "audiomxd", "mediaanalysisd",
        "calaccessd", "accountsd", "contactsd",
        "reminders", "corebrightnessd", "thermalmonitord",
        "watchdogd", "displaypolicyd", "distnoted",
        "softwareupdated", "appstoreagent",
        "driverkit", "iokitd", "kernelmanagerd",
        // Our app
        "ramcleanner",
    ]

    // System paths — never kill processes from these
    private let systemPathPrefixes: [String] = [
        "/system/", "/usr/sbin/", "/usr/libexec/",
        "/usr/bin/", "/sbin/", "/bin/",
        "/library/apple/", "/library/privilegedhelpertools/",
    ]

    init() {
        detectChipName()
        refresh()
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Timer

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - Detect Chip Name

    private func detectChipName() {
        var size: Int = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return }
        var brand = [CChar](repeating: 0, count: size)
        if sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0) == 0 {
            self.chipName = String(cString: brand)
        }
    }

    // MARK: - Refresh All Data

    func refresh() {
        fetchMemoryStats()
        fetchMemoryPressure()
        fetchTopProcesses()
    }

    // MARK: - Memory Statistics (matches Activity Monitor)

    private func fetchMemoryStats() {
        let hostPort = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, hostPort) }
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(hostPort, HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            lastError = "Failed to get VM statistics (kern result: \(result))"
            return
        }

        let pageSize = Double(vm_kernel_page_size)

        var totalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        let sysctlResult = sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0)

        guard sysctlResult == 0 else {
            lastError = "Failed to get total memory via sysctl"
            return
        }

        let totalBytes = Double(totalMemory)

        // Activity Monitor formula (closest match):
        // App Memory = (internal_page_count - purgeable_count) × pageSize
        // Wired Memory = wire_count × pageSize
        // Compressed = compressor_page_count × pageSize (physical compressor pages)
        // Memory Used = App Memory + Wired + Compressed
        // Note: ~4% difference from Activity Monitor is normal (GPU/IOKit overhead)
        let appMemory = Double(vmStats.internal_page_count - vmStats.purgeable_count) * pageSize
        let wiredMemory = Double(vmStats.wire_count) * pageSize
        let compressedMemory = Double(vmStats.compressor_page_count) * pageSize
        let usedBytes = appMemory + wiredMemory + compressedMemory

        let cachedBytes = Double(vmStats.external_page_count + vmStats.purgeable_count) * pageSize

        self.totalGB = totalBytes / 1_073_741_824
        self.usedGB = max(0, usedBytes / 1_073_741_824)
        self.cachedGB = cachedBytes / 1_073_741_824
        self.usagePercent = totalBytes > 0 ? min(100, Int((usedBytes / totalBytes) * 100)) : 0

        // Get swap usage via sysctl
        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0) == 0 {
            self.swapUsedMB = Double(swapUsage.xsu_used) / 1_048_576.0
        }

        lastError = nil
    }

    // MARK: - Memory Pressure

    private func fetchMemoryPressure() {
        if usagePercent < 60 {
            pressure = .low
        } else if usagePercent < 80 {
            pressure = .medium
        } else {
            pressure = .high
        }
    }

    // MARK: - Top 5 Processes by Memory Footprint

    private func fetchTopProcesses() {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        process.arguments = ["-l", "1", "-o", "mem", "-n", "10", "-stats", "pid,mem,command"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                lastError = "Failed to decode top output"
                return
            }

            let lines = output.components(separatedBy: "\n")
            var processes: [ProcessInfo] = []
            var foundHeader = false

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.hasPrefix("PID") {
                    foundHeader = true
                    continue
                }

                guard foundHeader, !trimmed.isEmpty else { continue }

                let components = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)

                guard components.count >= 3,
                      let pid = Int32(components[0]) else {
                    continue
                }

                let memString = String(components[1])
                let name = extractAppName(from: String(components[2]).trimmingCharacters(in: .whitespaces))
                let memoryMB = parseMemoryValue(memString)

                if memoryMB < 10 { continue }

                processes.append(ProcessInfo(pid: pid, name: name, memoryMB: memoryMB))

                if processes.count >= 5 { break }
            }

            self.topProcesses = processes

        } catch {
            lastError = "Failed to list processes: \(error.localizedDescription)"
        }
    }

    // MARK: - Parse memory values from top (e.g. "3490M", "1774M", "502M", "2G")

    private func parseMemoryValue(_ value: String) -> Double {
        let cleaned = value.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: "-", with: "")

        if cleaned.hasSuffix("G") {
            return (Double(String(cleaned.dropLast())) ?? 0) * 1024.0
        } else if cleaned.hasSuffix("M") {
            return Double(String(cleaned.dropLast())) ?? 0
        } else if cleaned.hasSuffix("K") {
            return (Double(String(cleaned.dropLast())) ?? 0) / 1024.0
        } else if cleaned.hasSuffix("B") {
            return (Double(String(cleaned.dropLast())) ?? 0) / 1_048_576.0
        } else {
            return Double(cleaned) ?? 0
        }
    }

    // MARK: - Helpers

    private func extractAppName(from path: String) -> String {
        let url = URL(fileURLWithPath: path)
        var name = url.lastPathComponent

        if !path.contains("/") {
            name = path
        }

        name = name
            .replacingOccurrences(of: " Helper (Renderer)", with: "")
            .replacingOccurrences(of: " Helper (GPU)", with: "")
            .replacingOccurrences(of: " Helper (Plugin)", with: "")
            .replacingOccurrences(of: " Helper", with: "")

        return name
    }

    // MARK: - 🧹 Clean Memory (Basic — purge only)

    func cleanMemory(completion: @escaping @Sendable (Bool, String) -> Void) {
        let usedBefore = usedGB

        let script = """
        do shell script "/usr/sbin/purge" with administrator privileges
        """

        DispatchQueue.global(qos: .userInitiated).async {
            let appleScript = NSAppleScript(source: script)
            var errorDict: NSDictionary?
            appleScript?.executeAndReturnError(&errorDict)

            DispatchQueue.main.async { [weak self] in
                if let error = errorDict {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    completion(false, message)
                } else {
                    self?.refresh()
                    let freed = max(0, usedBefore - (self?.usedGB ?? usedBefore))
                    completion(true, String(format: "✅ Freed %.1f GB (cache cleared)", freed))
                }
            }
        }
    }

    // MARK: - 🔥 Deep Clean Memory (kill ALL orphan processes + purge + clear caches)

    func deepCleanMemory(completion: @escaping @Sendable (Bool, String) -> Void) {
        let usedBefore = usedGB

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var steps: [String] = []
            var killedCount = 0
            var killedMB: Double = 0

            // Step 1: Find and kill ALL orphan processes from closed apps
            let orphans = self.findAllOrphanProcesses()
            for orphan in orphans {
                let result = self.killProcess(pid: orphan.pid)
                if result {
                    killedCount += 1
                    killedMB += orphan.memoryMB
                }
            }
            if killedCount > 0 {
                steps.append("Killed \(killedCount) orphan processes (\(Int(killedMB)) MB)")
            } else {
                steps.append("No orphan processes found")
            }

            // Step 2: Clear user caches and derived data
            let cacheSteps = self.clearUserCaches()
            steps.append(contentsOf: cacheSteps)

            // Step 3: Run purge to clear file system cache
            let purgeScript = """
            do shell script "/usr/sbin/purge" with administrator privileges
            """
            let appleScript = NSAppleScript(source: purgeScript)
            var errorDict: NSDictionary?
            appleScript?.executeAndReturnError(&errorDict)

            if errorDict == nil {
                steps.append("System memory cache purged")
            }

            // Step 4: Force apps to release cached memory
            self.sendMemoryWarningToApps()
            steps.append("Memory pressure signal sent")

            DispatchQueue.main.async { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.refresh()
                    let freed = max(0, usedBefore - (self?.usedGB ?? usedBefore))
                    let summary = String(format: "✅ Deep clean done! Freed ~%.1f GB", freed)
                    let details = summary + "\n" + steps.joined(separator: "\n")
                    completion(true, details)
                }
            }
        }
    }

    // MARK: - 🔍 Dynamic Orphan Detection (find ALL lingering processes from closed apps)

    /// Uses NSWorkspace to get currently active GUI apps, then compares against
    /// ALL running background processes to find orphans from apps that have been closed.
    /// This works for ANY app (Spotify, Adobe, Android Studio, etc.) — not just a hardcoded list.
    private func findAllOrphanProcesses() -> [ProcessInfo] {
        // Step 1: Get all currently active GUI apps from NSWorkspace
        let runningApps = NSWorkspace.shared.runningApplications
        var activeAppNames: Set<String> = []
        var activeBundleIDs: Set<String> = []
        var activePIDs: Set<Int32> = []

        for app in runningApps {
            activePIDs.insert(app.processIdentifier)

            if let bundleID = app.bundleIdentifier {
                activeBundleIDs.insert(bundleID.lowercased())
                // Extract short name from bundle ID: com.spotify.client -> spotify
                let parts = bundleID.lowercased().split(separator: ".")
                for part in parts {
                    if part.count > 2 && part != "com" && part != "app" && part != "helper" {
                        activeAppNames.insert(String(part))
                    }
                }
            }
            if let name = app.localizedName {
                activeAppNames.insert(name.lowercased())
            }
            if let url = app.executableURL {
                let fullPath = url.path
                // Extract .app name: /Applications/Spotify.app/Contents/MacOS/Spotify -> spotify
                if let appRange = fullPath.range(of: ".app/") ?? fullPath.range(of: ".app") {
                    let appPath = String(fullPath[..<appRange.lowerBound])
                    let appName = URL(fileURLWithPath: appPath).lastPathComponent
                    activeAppNames.insert(appName.lowercased())
                }
            }
        }

        // Step 2: Get ALL running processes from ps with full path
        let allProcesses = getAllProcessesWithPath()

        // Step 3: For each process, determine if its parent app is NOT running
        var orphans: [ProcessInfo] = []
        var seenPIDs: Set<Int32> = []
        let myPID = getpid()

        for proc in allProcesses {
            guard proc.pid != myPID else { continue }
            guard !activePIDs.contains(proc.pid) else { continue }  // Skip active app PIDs
            guard !seenPIDs.contains(proc.pid) else { continue }
            guard proc.memoryMB > 15 else { continue }             // Only processes > 15MB

            let pathLower = proc.name.lowercased()
            let baseName = URL(fileURLWithPath: proc.name).lastPathComponent.lowercased()

            // Skip system-critical processes
            if isSystemCritical(pathLower, baseName: baseName) { continue }

            // Case A: Process is inside a .app bundle
            if let appRange = pathLower.range(of: ".app/") {
                let appPath = String(pathLower[..<appRange.lowerBound])
                let appName = URL(fileURLWithPath: appPath).lastPathComponent

                // If the parent .app is NOT in the active apps list, it's an orphan
                let isActive = activeAppNames.contains(appName) ||
                    activeBundleIDs.contains(where: { $0.contains(appName) })

                if !isActive {
                    orphans.append(proc)
                    seenPIDs.insert(proc.pid)
                }
                continue
            }

            // Case B: Background helper/daemon (not inside .app)
            // Identify likely helpers by name patterns
            let helperIndicators = [
                "helper", "agent", "daemon", "service",
                "crashpad", "renderer", "gpu-process", "gpu_process",
                "cef", "electron", "framework",
                "worker", "broker", "host",
            ]
            let looksLikeHelper = helperIndicators.contains(where: { baseName.contains($0) })

            if looksLikeHelper {
                // Check if ANY active app name appears in this process path
                let matchesActiveApp = activeAppNames.contains(where: { appName in
                    baseName.contains(appName) || pathLower.contains(appName)
                })

                if !matchesActiveApp {
                    orphans.append(proc)
                    seenPIDs.insert(proc.pid)
                }
            }
        }

        return orphans
    }

    // MARK: - Get All Processes with Full Path

    private func getAllProcessesWithPath() -> [ProcessInfo] {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,rss=,comm="]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            var processes: [ProcessInfo] = []
            let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let components = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)

                guard components.count >= 3,
                      let pid = Int32(components[0]),
                      let rssKB = Double(components[1]) else {
                    continue
                }

                let fullPath = String(components[2])
                processes.append(ProcessInfo(pid: pid, name: fullPath, memoryMB: rssKB / 1024.0))
            }

            return processes
        } catch {
            return []
        }
    }

    // MARK: - Kill Process

    private func killProcess(pid: Int32) -> Bool {
        return kill(pid, SIGTERM) == 0
    }

    // MARK: - System Critical Processes (never kill these)

    private func isSystemCritical(_ pathLower: String, baseName: String) -> Bool {
        // Check name against critical list
        let nameNoExt = baseName.replacingOccurrences(of: ".app", with: "")
        if systemCriticalNames.contains(nameNoExt) {
            return true
        }

        // Never kill processes from system paths
        for prefix in systemPathPrefixes {
            if pathLower.hasPrefix(prefix) {
                return true
            }
        }

        // Never kill Apple's own XPC services
        if pathLower.contains("com.apple.") {
            return true
        }

        // Never kill processes from /Library/Apple
        if pathLower.contains("/library/apple/") {
            return true
        }

        return false
    }

    // MARK: - Clear User Caches

    private func clearUserCaches() -> [String] {
        var results: [String] = []
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        // Clear Xcode DerivedData (often several GB)
        let derivedData = "\(homeDir)/Library/Developer/Xcode/DerivedData"
        if clearDirectory(derivedData) {
            results.append("Xcode DerivedData cleared")
        }

        // Clear specific app caches (not all caches)
        let userCaches = "\(homeDir)/Library/Caches"
        let tempDirs = [
            "\(userCaches)/com.apple.dt.Xcode",
            "\(userCaches)/org.carthage.CarthageKit",
            "\(userCaches)/com.googlecode.iterm2",
            "\(userCaches)/Google",
            "\(userCaches)/JetBrains",
        ]

        for dir in tempDirs {
            if clearDirectory(dir) {
                let name = URL(fileURLWithPath: dir).lastPathComponent
                results.append("Cache cleared: \(name)")
            }
        }

        // Clear Gradle caches (Android Studio)
        let gradleCaches = "\(homeDir)/.gradle/caches"
        if clearDirectory(gradleCaches) {
            results.append("Gradle caches cleared")
        }

        return results
    }

    private func clearDirectory(_ path: String) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return false }

        do {
            let items = try fm.contentsOfDirectory(atPath: path)
            for item in items {
                try fm.removeItem(atPath: "\(path)/\(item)")
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Send Memory Pressure Signal

    private func sendMemoryWarningToApps() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/memory_pressure")
        process.arguments = ["-l", "warn"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                if process.isRunning {
                    process.terminate()
                }
            }
        } catch {
            // memory_pressure not available on this system
        }
    }
}
