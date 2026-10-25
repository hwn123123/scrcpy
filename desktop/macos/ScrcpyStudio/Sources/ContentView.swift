import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 330)
        } detail: {
            detail
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(.blue.gradient).frame(width: 42, height: 42)
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scrcpy Studio").font(.system(size: 20, weight: .bold))
                        Text("设备与投屏控制台").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(model.statusText).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
            HStack {
                Text("设备").font(.headline)
                Spacer()
                if model.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Button { model.refreshDevices() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain).help("刷新设备")
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 12)

            List(model.devices, selection: $model.selectedSerial) { device in
                DeviceRow(device: device).tag(device.serial)
            }
            .listStyle(.sidebar)

            Divider()
            VStack(alignment: .leading, spacing: 9) {
                Text("无线连接").font(.headline)
                HStack(spacing: 7) {
                    TextField("手机 IP 或 IP:端口", text: $model.connectAddress)
                        .textFieldStyle(.roundedBorder).onSubmit { model.connectWireless() }
                    Button("连接") { model.connectWireless() }.buttonStyle(.borderedProminent)
                }
                Button("将 USB 设备切换为无线连接") { model.enableWirelessFromUSB() }
                    .buttonStyle(.borderless).disabled(model.selectedDevice == nil)
            }
            .padding(18)
        }
    }

    private var detail: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.08), Color(nsColor: .windowBackgroundColor), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    HStack(alignment: .top, spacing: 16) {
                        qualityCard
                        behaviorCard
                    }
                    actionCard
                    logCard
                }
                .padding(26).frame(maxWidth: 980).frame(maxWidth: .infinity)
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(.blue.gradient).frame(width: 88, height: 88)
                Image(systemName: model.selectedDevice?.isWireless == true ? "wifi" : "cable.connector")
                    .font(.system(size: 36, weight: .medium)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(model.selectedDevice?.displayName ?? "请选择手机").font(.system(size: 29, weight: .bold))
                Text(model.selectedDevice.map { "\($0.serial) · \($0.isWireless ? "无线" : "USB")" } ?? "连接手机后点击左侧刷新")
                    .foregroundStyle(.secondary)
                if let product = model.selectedDevice?.product, !product.isEmpty {
                    Text(product).font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button {
                model.isMirroring ? model.stopMirroring() : model.startMirroring()
            } label: {
                Label(model.isMirroring ? "停止投屏" : "开始投屏", systemImage: model.isMirroring ? "stop.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold)).frame(minWidth: 116)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .tint(model.isMirroring ? .red : .blue)
            .disabled(model.selectedDevice?.isOnline != true)
        }
        .studioCard()
    }

    private var qualityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("画面质量", systemImage: "sparkles.tv").font(.headline)
            FormRow("分辨率") {
                Picker("", selection: $model.profile.maxSize) {
                    Text("1280").tag(1280); Text("1920").tag(1920); Text("2560").tag(2560); Text("原始").tag(0)
                }.labelsHidden().frame(width: 120)
            }
            FormRow("视频码率") {
                Picker("", selection: $model.profile.bitRate) {
                    Text("8 Mbps").tag("8M"); Text("12 Mbps").tag("12M"); Text("20 Mbps").tag("20M"); Text("30 Mbps").tag("30M")
                }.labelsHidden().frame(width: 120)
            }
            FormRow("最高帧率") {
                Picker("", selection: $model.profile.maxFps) {
                    Text("30 FPS").tag(30); Text("60 FPS").tag(60); Text("120 FPS").tag(120); Text("不限制").tag(0)
                }.labelsHidden().frame(width: 120)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).studioCard()
    }

    private var behaviorCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("设备行为", systemImage: "switch.2").font(.headline)
            Toggle("传输手机声音", isOn: $model.profile.audio)
            Toggle("投屏时关闭手机屏幕", isOn: $model.profile.turnScreenOff)
            Toggle("连接期间保持唤醒", isOn: $model.profile.stayAwake)
            Toggle("在手机上显示触摸位置", isOn: $model.profile.showTouches)
            Toggle("同时录制为 MP4", isOn: $model.profile.record)
        }
        .toggleStyle(.switch).frame(maxWidth: .infinity, alignment: .leading).studioCard()
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("快捷操作", systemImage: "bolt.fill").font(.headline)
            HStack(spacing: 10) {
                Button { model.installAPK() } label: { Label("安装 APK", systemImage: "shippingbox") }
                Button { model.pushFile() } label: { Label("传文件到 Download", systemImage: "arrow.up.doc") }
                if model.selectedDevice?.isWireless == true {
                    Button(role: .destructive) { model.disconnectWireless() } label: { Label("断开无线连接", systemImage: "wifi.slash") }
                }
                Spacer()
            }
            .buttonStyle(.bordered).disabled(model.selectedDevice == nil)
        }
        .studioCard()
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("运行日志", systemImage: "terminal").font(.headline)
                Spacer()
                Button("清空") { model.clearLog() }.buttonStyle(.borderless)
            }
            ScrollView {
                Text(model.logText.isEmpty ? "暂无日志" : model.logText)
                    .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 120).padding(10)
            .background(Color.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 9))
            .foregroundStyle(Color.green.opacity(0.9))
        }
        .studioCard()
    }
}

private struct DeviceRow: View {
    let device: AndroidDevice
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(device.isOnline ? Color.green.opacity(0.18) : Color.red.opacity(0.18)).frame(width: 34, height: 34)
                Image(systemName: device.isWireless ? "wifi" : "iphone").foregroundStyle(device.isOnline ? .green : .red)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName).fontWeight(.medium)
                Text(device.serial).font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FormRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        HStack { Text(title).foregroundStyle(.secondary); Spacer(); content }
    }
}

private extension View {
    func studioCard() -> some View {
        self.padding(19)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.07), lineWidth: 1) }
            .shadow(color: .black.opacity(0.04), radius: 12, y: 5)
    }
}
