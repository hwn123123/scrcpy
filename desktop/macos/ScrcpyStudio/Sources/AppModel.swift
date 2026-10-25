import AppKit
import Foundation
import UniformTypeIdentifiers

struct AndroidDevice: Identifiable, Hashable {
    let serial: String
    let state: String
    let model: String
    let product: String

    var id: String { serial }
    var isOnline: Bool { state == "device" }
    var isWireless: Bool { serial.contains(":") }
    var displayName: String { model.isEmpty ? serial : model.replacingOccurrences(of: "_", with: " ") }
}

struct MirrorProfile {
    var maxSize = 1920
    var bitRate = "12M"
    var maxFps = 60
    var audio = true
    var turnScreenOff = false
    var stayAwake = true
    var showTouches = false
    var record = false
}

@MainActor
final class AppModel: ObservableObject {
    @Published var devices: [AndroidDevice] = []
    @Published var selectedSerial: String?
    @Published var connectAddress = ""
    @Published var profile = MirrorProfile()
    @Published var isRefreshing = false
    @Published var isMirroring = false
    @Published var statusText = "准备就绪"
    @Published var logText = "Scrcpy Studio 已启动。\n"

    private var scrcpyProcess: Process?

    init() {
        refreshDevices()
    }

    var selectedDevice: AndroidDevice? {
        devices.first { $0.serial == selectedSerial }
    }

    var toolDirectory: URL {
        if let resource = Bundle.main.resourceURL?.appendingPathComponent("scrcpy"),
           FileManager.default.isExecutableFile(atPath: resource.appendingPathComponent("scrcpy").path) {
            return resource
        }
        if let custom = ProcessInfo.processInfo.environment["SCRCPY_HOME"] {
            return URL(fileURLWithPath: custom)
        }
        return URL(fileURLWithPath: "/Users/ning/Applications/scrcpy-5.0.1")
    }

    private var adbURL: URL { toolDirectory.appendingPathComponent("adb") }
    private var scrcpyURL: URL { toolDirectory.appendingPathComponent("scrcpy") }
    private var serverURL: URL { toolDirectory.appendingPathComponent("scrcpy-server") }

    func refreshDevices() {
        guard !isRefreshing else { return }
        isRefreshing = true
        statusText = "正在扫描设备…"
        let adb = adbURL
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.run(executable: adb, arguments: ["devices", "-l"])
            let parsed = Self.parseDevices(result.output)
            DispatchQueue.main.async {
                self.devices = parsed
                if self.selectedSerial == nil || !parsed.contains(where: { $0.serial == self.selectedSerial }) {
                    self.selectedSerial = parsed.first(where: { $0.isOnline })?.serial
                }
                self.isRefreshing = false
                self.statusText = parsed.isEmpty ? "未发现设备" : "发现 \(parsed.count) 台设备"
                self.appendLog(result.output)
            }
        }
    }

    func connectWireless() {
        var address = connectAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            statusText = "请输入手机 IP"
            return
        }
        if !address.contains(":") { address += ":5555" }
        statusText = "正在连接 \(address)…"
        runADB(["connect", address]) { result in
            self.statusText = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            self.refreshDevices()
        }
    }

    func disconnectWireless() {
        guard let device = selectedDevice, device.isWireless else { return }
        runADB(["disconnect", device.serial]) { result in
            self.statusText = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            self.refreshDevices()
        }
    }

    func enableWirelessFromUSB() {
        guard let device = selectedDevice, device.isOnline else { return }
        statusText = "正在切换到无线模式…"
        let serial = device.serial
        let adb = adbURL
        DispatchQueue.global(qos: .userInitiated).async {
            let route = Self.run(executable: adb, arguments: ["-s", serial, "shell", "ip", "route"]).output
            let ip = Self.extractSourceIP(route)
            let tcp = Self.run(executable: adb, arguments: ["-s", serial, "tcpip", "5555"])
            Thread.sleep(forTimeInterval: 1.2)
            let connect = ip.isEmpty ? nil : Self.run(executable: adb, arguments: ["connect", "\(ip):5555"])
            DispatchQueue.main.async {
                self.appendLog(tcp.output)
                if let connect { self.appendLog(connect.output) }
                self.statusText = ip.isEmpty ? "未能读取手机 Wi-Fi 地址" : "无线地址：\(ip):5555"
                self.connectAddress = ip
                self.refreshDevices()
            }
        }
    }

    func startMirroring() {
        guard let device = selectedDevice, device.isOnline else {
            statusText = "请先选择在线设备"
            return
        }
        guard FileManager.default.isExecutableFile(atPath: scrcpyURL.path) else {
            statusText = "找不到 scrcpy 可执行文件"
            return
        }

        var arguments = ["--serial", device.serial]
        if profile.maxSize > 0 { arguments += ["--max-size", "\(profile.maxSize)"] }
        if !profile.bitRate.isEmpty { arguments += ["--video-bit-rate", profile.bitRate] }
        if profile.maxFps > 0 { arguments += ["--max-fps", "\(profile.maxFps)"] }
        if !profile.audio { arguments.append("--no-audio") }
        if profile.turnScreenOff { arguments.append("--turn-screen-off") }
        if profile.stayAwake { arguments.append("--stay-awake") }
        if profile.showTouches { arguments.append("--show-touches") }

        if profile.record {
            let panel = NSSavePanel()
            panel.title = "保存手机录屏"
            panel.nameFieldStringValue = "手机录屏-\(Self.timestamp()).mp4"
            panel.allowedContentTypes = [.mpeg4Movie]
            guard panel.runModal() == .OK, let url = panel.url else {
                statusText = "已取消录屏"
                return
            }
            arguments += ["--record", url.path]
        }

        let process = Process()
        process.executableURL = scrcpyURL
        process.arguments = arguments
        process.currentDirectoryURL = toolDirectory
        var environment = ProcessInfo.processInfo.environment
        environment["SCRCPY_SERVER_PATH"] = serverURL.path
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.appendLog(text) }
        }
        process.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                pipe.fileHandleForReading.readabilityHandler = nil
                self?.isMirroring = false
                self?.scrcpyProcess = nil
                self?.statusText = finished.terminationStatus == 0 ? "投屏已结束" : "投屏异常结束"
            }
        }

        do {
            try process.run()
            scrcpyProcess = process
            isMirroring = true
            statusText = "正在投屏 \(device.displayName)"
            appendLog("$ scrcpy \(arguments.joined(separator: " "))\n")
        } catch {
            statusText = "启动失败：\(error.localizedDescription)"
        }
    }

    func stopMirroring() {
        scrcpyProcess?.terminate()
        statusText = "正在停止投屏…"
    }

    func installAPK() {
        guard let serial = selectedSerial else { return }
        let panel = NSOpenPanel()
        panel.title = "选择要安装的 APK"
        panel.allowedContentTypes = [UTType(filenameExtension: "apk") ?? .data]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let file = panel.url else { return }
        statusText = "正在安装 \(file.lastPathComponent)…"
        runADB(["-s", serial, "install", "-r", file.path]) { result in
            self.statusText = result.status == 0 ? "APK 安装完成" : "APK 安装失败"
        }
    }

    func pushFile() {
        guard let serial = selectedSerial else { return }
        let panel = NSOpenPanel()
        panel.title = "选择要传到手机的文件"
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let file = panel.url else { return }
        statusText = "正在传输 \(file.lastPathComponent)…"
        runADB(["-s", serial, "push", file.path, "/sdcard/Download/"]) { result in
            self.statusText = result.status == 0 ? "文件已传到 Download" : "文件传输失败"
        }
    }

    func clearLog() { logText = "" }

    private func runADB(_ arguments: [String], completion: @escaping (CommandResult) -> Void) {
        let adb = adbURL
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.run(executable: adb, arguments: arguments)
            DispatchQueue.main.async {
                self.appendLog("$ adb \(arguments.joined(separator: " "))\n\(result.output)\n")
                completion(result)
            }
        }
    }

    private func appendLog(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        logText += text.hasSuffix("\n") ? text : text + "\n"
        if logText.count > 24_000 { logText = String(logText.suffix(20_000)) }
    }

    nonisolated private static func run(executable: URL, arguments: [String]) -> CommandResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return CommandResult(status: process.terminationStatus, output: String(data: data, encoding: .utf8) ?? "")
        } catch {
            return CommandResult(status: -1, output: error.localizedDescription)
        }
    }

    nonisolated private static func parseDevices(_ output: String) -> [AndroidDevice] {
        output.split(separator: "\n").dropFirst().compactMap { rawLine in
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { return nil }
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard fields.count >= 2 else { return nil }
            var metadata: [String: String] = [:]
            for field in fields.dropFirst(2) {
                let parts = field.split(separator: ":", maxSplits: 1).map(String.init)
                if parts.count == 2 { metadata[parts[0]] = parts[1] }
            }
            return AndroidDevice(serial: fields[0], state: fields[1], model: metadata["model"] ?? "", product: metadata["product"] ?? "")
        }
    }

    nonisolated private static func extractSourceIP(_ route: String) -> String {
        let tokens = route.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)
        guard let index = tokens.firstIndex(of: "src"), index + 1 < tokens.count else { return "" }
        return tokens[index + 1]
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

struct CommandResult {
    let status: Int32
    let output: String
}
