import Foundation
import Darwin
import AppKit
import LocalAuthentication

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

    private var backgroundTimer: Timer?
    private var foregroundTimer: Timer?
    private let updateInterval: TimeInterval = 3.0

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
        "ramcleaner",
    ]

    // System paths — never kill processes from these
    private let systemPathPrefixes: [String] = [
        "/system/", "/usr/sbin/", "/usr/libexec/",
        "/usr/bin/", "/sbin/", "/bin/",
        "/library/apple/", "/library/privilegedhelpertools/",
    ]

    init() {
        detectChipName()
        fetchMemoryStats()
        fetchMemoryPressure()
        fetchTopProcesses()
        startBackgroundTimer()
    }

    deinit {
        backgroundTimer?.invalidate()
        foregroundTimer?.invalidate()
    }

    // MARK: - Timer

    func startBackgroundTimer() {
        // Must run on main thread — Timer requires main RunLoop to fire reliably
        if Thread.isMainThread {
            backgroundTimer?.invalidate()
            backgroundTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.fetchMemoryStats()
                self?.fetchMemoryPressure()
            }
            RunLoop.main.add(backgroundTimer!, forMode: .common)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.startBackgroundTimer()
            }
        }
    }

    func startForegroundTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.foregroundTimer?.invalidate()
            self.fetchTopProcesses()
            self.foregroundTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.fetchTopProcesses()
            }
            RunLoop.main.add(self.foregroundTimer!, forMode: .common)
        }
    }

    func stopForegroundTimer() {
        foregroundTimer?.invalidate()
        foregroundTimer = nil
    }

    // MARK: - Detect Chip Name

    private func detectChipName() {
        var size: Int = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return }
        var modelChars = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &modelChars, &size, nil, 0) == 0 else { return }
        let model = String(cString: modelChars)

        // Apple Silicon model mapping (verified against Apple's identifiers)
        switch true {
        case model.hasPrefix("Mac12,"):
            self.chipName = "Apple M1"
        case model.hasPrefix("Mac13,"):
            // Mac13,1 = MacBook Pro 14" M1 Pro
            // Mac13,2 = MacBook Pro 16" M1 Max
            // Mac13,3 = Mac Studio M1 Max
            // Mac13,4 = Mac Studio M1 Ultra
            self.chipName = "Apple M1"
        case model.hasPrefix("Mac14,"):
            self.chipName = "Apple M2"
        case model.hasPrefix("Mac15,"):
            self.chipName = "Apple M3"
        case model.hasPrefix("Mac16,"):
            self.chipName = "Apple M4"
        default:
            // Fallback: try Intel brand string
            var brandSize: Int = 0
            sysctlbyname("machdep.cpu.brand_string", nil, &brandSize, nil, 0)
            if brandSize > 0 {
                var brandChars = [CChar](repeating: 0, count: brandSize)
                if sysctlbyname("machdep.cpu.brand_string", &brandChars, &brandSize, nil, 0) == 0 {
                    let brand = String(cString: brandChars)
                    if !brand.isEmpty {
                        self.chipName = brand
                        return
                    }
                }
            }
            self.chipName = "Apple Silicon (\(model))"
        }
    }

    // MARK: - Refresh All Data

    func refresh() {
        fetchMemoryStats()
        fetchMemoryPressure()
        fetchTopProcesses()
    }

    // MARK: - Memory Statistics (matches Activity Monitor)

    func fetchMemoryStats() {
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

    func fetchMemoryPressure() {
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
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
                    DispatchQueue.main.async { self?.lastError = "Failed to decode top output" }
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
                    let name = self?.extractAppName(from: String(components[2]).trimmingCharacters(in: .whitespaces)) ?? ""
                    let memoryMB = self?.parseMemoryValue(memString) ?? 0

                    if memoryMB < 10 { continue }

                    processes.append(ProcessInfo(pid: pid, name: name, memoryMB: memoryMB))

                    if processes.count >= 5 { break }
                }

                DispatchQueue.main.async {
                    self?.topProcesses = processes
                }

            } catch {
                DispatchQueue.main.async {
                    self?.lastError = "Failed to list processes: \(error.localizedDescription)"
                }
            }
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

    // MARK: - Local Authentication & Smart Purge

    private func executeWithTouchID(reason: String, action: @escaping @Sendable () -> Void, fallback: @escaping @Sendable (String) -> Void) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, evalError in
                if success {
                    action()
                } else {
                    fallback("Touch ID Canceled")
                }
            }
        } else {
            // Touch ID not available, proceed immediately (will show password prompt if needed)
            action()
        }
    }

    private func performSmartPurge(usedBefore: Double, isDeepClean: Bool = false, completion: @escaping @Sendable (Bool, String) -> Void) {
        // Attempt 1: Try silent sudo purge (works if sudoers is already configured)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "/usr/sbin/purge"] // -n fails immediately if password needed
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                // Success natively without password!
                if !isDeepClean {
                    self.finishPurge(usedBefore: usedBefore, prefix: "", completion: completion)
                } else {
                    completion(true, "System memory cache purged")
                }
                return
            }
        } catch {
            // Ignored, fallback to AppleScript
        }
        
        // Attempt 2: Setup sudoers and run purge using AppleScript with admin privileges
        let currentUser = NSUserName()
        let script = """
        do shell script "mkdir -p /private/etc/sudoers.d && echo '\(currentUser) ALL=(ALL) NOPASSWD: /usr/sbin/purge' > /private/etc/sudoers.d/ramcleaner_\(currentUser) && chmod 440 /private/etc/sudoers.d/ramcleaner_\(currentUser) && /usr/sbin/purge" with prompt "RamCleaner needs your password once to enable Touch ID for future cleaning!" with administrator privileges
        """
        
        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        
        DispatchQueue.global(qos: .userInitiated).async {
            appleScript?.executeAndReturnError(&errorDict)
            
            DispatchQueue.main.async { [weak self] in
                if let error = errorDict {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Authorization failed"
                    completion(false, message)
                } else {
                    if !isDeepClean {
                        self?.finishPurge(usedBefore: usedBefore, prefix: "(Setup Complete) ", completion: completion)
                    } else {
                        completion(true, "System memory cache purged")
                    }
                }
            }
        }
    }

    private func finishPurge(usedBefore: Double, prefix: String, completion: @escaping @Sendable (Bool, String) -> Void) {
        DispatchQueue.main.async { [weak self] in
            self?.fetchMemoryStats()
            self?.fetchMemoryPressure()
            let freed = max(0, usedBefore - (self?.usedGB ?? usedBefore))
            completion(true, String(format: "✅ \(prefix)Freed %.1f GB", freed))
            self?.fetchTopProcesses()
        }
    }

    // MARK: - 🧹 Clean Memory (Basic — purge only)

    func cleanMemory(completion: @escaping @Sendable (Bool, String) -> Void) {
        let usedBefore = usedGB
        executeWithTouchID(reason: "Scan fingerprint to Quick Clean RAM") { [weak self] in
            self?.performSmartPurge(usedBefore: usedBefore, isDeepClean: false, completion: completion)
        } fallback: { errorMsg in
            DispatchQueue.main.async { completion(false, errorMsg) }
        }
    }

    // MARK: - 🔥 Deep Clean Memory (kill ALL orphan processes + purge + clear caches)

    func deepCleanMemory(completion: @escaping @Sendable (Bool, String) -> Void) {
        let usedBefore = usedGB

        executeWithTouchID(reason: "Scan fingerprint to Deep Clean RAM") { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
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

                // Step 3 & 4: Smart Purge + Force apps to release cached memory
                DispatchQueue.main.async {
                    self.performSmartPurge(usedBefore: usedBefore, isDeepClean: true) { success, msg in
                        if success {
                            if msg == "System memory cache purged" {
                                steps.append(msg)
                            }
                            
                            self.sendMemoryWarningToApps()
                            steps.append("Memory pressure signal sent")

                            DispatchQueue.main.async {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    self.fetchMemoryStats()
                                    self.fetchMemoryPressure()
                                    let freed = max(0, usedBefore - self.usedGB)
                                    let summary = String(format: "✅ Deep clean done! Freed ~%.1f GB", freed)
                                    let details = summary + "\n" + steps.joined(separator: "\n")
                                    completion(true, details)
                                    self.fetchTopProcesses()
                                }
                            }
                        } else {
                            // Purge failed (password canceled)
                            DispatchQueue.main.async { completion(false, msg) }
                        }
                    }
                }
            }
        } fallback: { errorMsg in
            DispatchQueue.main.async { completion(false, errorMsg) }
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
        var activeExecPaths: Set<String> = []
        var activePIDs: Set<Int32> = []

        for app in runningApps {
            activePIDs.insert(app.processIdentifier)

            if let bundleID = app.bundleIdentifier?.lowercased() {
                activeBundleIDs.insert(bundleID)
                // Extract short name from bundle ID: com.spotify.client -> spotify
                let parts = bundleID.split(separator: ".")
                for part in parts {
                    if part.count > 2 && part != "com" && part != "app" && part != "helper" {
                        activeAppNames.insert(String(part))
                    }
                }
            }
            if let name = app.localizedName?.lowercased() {
                activeAppNames.insert(name)
            }
            if let execPath = app.executableURL?.path.lowercased() {
                activeExecPaths.insert(execPath)
                // Extract .app name: /Applications/Spotify.app/Contents/MacOS/Spotify -> spotify
                if let appRange = execPath.range(of: ".app/") ?? execPath.range(of: ".app") {
                    let appPath = String(execPath[..<appRange.lowerBound])
                    let appName = URL(fileURLWithPath: appPath).lastPathComponent
                    activeAppNames.insert(appName)
                }
            }
        }

        // Step 2: Get ALL running processes from ps with full path and PPID
        let allProcessesWithPPID = getAllProcessesWithPathWithPPID()
        let allPIDs = Set(allProcessesWithPPID.map { $0.proc.pid })

        // Step 3: Check orphan conditions
        var orphans: [ProcessInfo] = []
        var seenPIDs: Set<Int32> = []
        let myPID = getpid()

        for item in allProcessesWithPPID {
            let proc = item.proc
            let ppid = item.ppid

            guard proc.pid != myPID else { continue }
            guard !activePIDs.contains(proc.pid) else { continue }  // Skip active app PIDs
            guard !seenPIDs.contains(proc.pid) else { continue }
            guard proc.memoryMB > 15 else { continue }             // Only processes > 15MB

            let pathLower = proc.name.lowercased()
            let baseName = URL(fileURLWithPath: proc.name).lastPathComponent.lowercased()

            // Strict block list filtering
            if pathLower.hasPrefix("/system/") ||
               pathLower.hasPrefix("/usr/") ||
               pathLower.hasPrefix("/sbin/") ||
               pathLower.hasPrefix("/bin/") ||
               pathLower.hasPrefix("/library/apple/") ||
               pathLower.contains("com.apple.") ||
               isSystemCritical(pathLower, baseName: baseName) {
                continue
            }

            var isOrphan = false

            // Case A: Process is inside a .app bundle of an app that is NOT running
            if let appRange = pathLower.range(of: ".app/") {
                let appPath = String(pathLower[..<appRange.lowerBound])
                let appName = URL(fileURLWithPath: appPath).lastPathComponent

                let matchesActive = activeAppNames.contains(appName) ||
                                    activeBundleIDs.contains(where: { $0.contains(appName) }) ||
                                    activeExecPaths.contains(where: { $0.contains(appName) })

                if !matchesActive {
                    isOrphan = true
                }
            }

            // Case B: parent is dead (ppid not in process table), and ppid != 1
            if !isOrphan && ppid != 1 && !allPIDs.contains(ppid) {
                isOrphan = true
            }

            // Case C: adopted by launchd (ppid == 1) and looks like a helper of a dead app
            if !isOrphan && ppid == 1 {
                let helperIndicators = [
                    "helper", "renderer", "crashpad", "gpu", "worker", "broker", "electron"
                ]
                let looksLikeHelper = helperIndicators.contains(where: { baseName.contains($0) })
                
                if looksLikeHelper {
                    let matchesActiveApp = activeAppNames.contains(where: { appName in
                        baseName.contains(appName) || pathLower.contains(appName)
                    }) || activeBundleIDs.contains(where: { bundleID in
                        pathLower.contains(bundleID)
                    })
                    
                    if !matchesActiveApp {
                        isOrphan = true
                    }
                }
            }

            if isOrphan {
                orphans.append(proc)
                seenPIDs.insert(proc.pid)
            }
        }

        return orphans
    }

    // MARK: - Get All Processes with Full Path

    private func getAllProcessesWithPath() -> [ProcessInfo] {
        return getAllProcessesWithPathWithPPID().map { $0.proc }
    }

    private func getAllProcessesWithPathWithPPID() -> [(proc: ProcessInfo, ppid: Int32)] {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,ppid=,rss=,args="]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            var processes: [(proc: ProcessInfo, ppid: Int32)] = []
            let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let components = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)

                guard components.count >= 4,
                      let pid = Int32(components[0]),
                      let ppid = Int32(components[1]),
                      let rssKB = Double(components[2]) else {
                    continue
                }

                let fullPath = String(components[3])
                processes.append((proc: ProcessInfo(pid: pid, name: fullPath, memoryMB: rssKB / 1024.0), ppid: ppid))
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
        // Check if Xcode is running first to avoid breaking active builds!
        let xcodeIsRunning = NSWorkspace.shared.runningApplications
            .contains { $0.bundleIdentifier == "com.apple.dt.Xcode" }
        
        if !xcodeIsRunning {
            let derivedData = "\(homeDir)/Library/Developer/Xcode/DerivedData"
            if clearDirectory(derivedData) {
                results.append("Xcode DerivedData cleared")
            }
        } else {
            results.append("Xcode is running, skipped DerivedData")
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
