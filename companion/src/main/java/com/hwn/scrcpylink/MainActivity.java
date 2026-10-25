package com.hwn.scrcpylink;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.provider.Settings;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.Inet4Address;
import java.net.NetworkInterface;
import java.util.Collections;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends Activity {
    private int BLUE;
    private int TEXT;
    private int MUTED;
    private int GREEN;
    private int RED;
    private int BACKGROUND;
    private int SURFACE;
    private int STROKE;
    private boolean darkMode;

    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private TextView ipValue;
    private TextView portValue;
    private TextView usbValue;
    private TextView rootValue;
    private TextView commandValue;
    private Button enableButton;
    private String currentAddress = "";

    @Override
    @SuppressWarnings("deprecation")
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        loadPalette();
        Window window = getWindow();
        window.setStatusBarColor(BACKGROUND);
        window.setNavigationBarColor(BACKGROUND);
        window.getDecorView().setSystemUiVisibility(darkMode ? 0 : View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);
        setContentView(buildContent());
        refreshStatus();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (ipValue != null) refreshStatus();
    }

    @Override
    protected void onDestroy() {
        worker.shutdownNow();
        super.onDestroy();
    }

    private View buildContent() {
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setBackgroundColor(BACKGROUND);
        LinearLayout root = column();
        root.setPadding(dp(22), dp(24), dp(22), dp(32));
        applySystemBarInsets(root);
        scroll.addView(root, matchWrap());

        TextView title = text("让手机随时可连接", 30, TEXT, Typeface.BOLD);
        LinearLayout.LayoutParams titleParams = wrap();
        root.addView(title, titleParams);
        TextView subtitle = text("通过 USB 或局域网连接 Mac。无线模式仅在需要时开启，关闭后端口立即停止监听。", 15, MUTED, Typeface.NORMAL);
        subtitle.setLineSpacing(dp(3), 1f);
        LinearLayout.LayoutParams subtitleParams = wrap();
        subtitleParams.topMargin = dp(9);
        subtitleParams.bottomMargin = dp(22);
        root.addView(subtitle, subtitleParams);

        LinearLayout statusCard = card();
        root.addView(statusCard, cardParams());
        statusCard.addView(sectionTitle("连接状态"));
        ipValue = addRow(statusCard, "本机 IP", "正在读取…");
        portValue = addRow(statusCard, "无线 ADB", "正在读取…");
        usbValue = addRow(statusCard, "USB 调试", "正在读取…");
        rootValue = addRow(statusCard, "Root 权限", "等待授权…");

        LinearLayout commandCard = card();
        LinearLayout.LayoutParams commandParams = cardParams();
        commandParams.topMargin = dp(14);
        root.addView(commandCard, commandParams);
        commandCard.addView(sectionTitle("Mac 连接地址"));
        commandValue = text("等待网络连接", 17, TEXT, Typeface.BOLD);
        commandValue.setPadding(0, dp(12), 0, dp(10));
        commandCard.addView(commandValue, matchWrap());
        Button copy = secondaryButton("复制 adb connect 命令");
        copy.setOnClickListener(v -> copyCommand());
        commandCard.addView(copy, buttonParams());

        enableButton = primaryButton("开启无线连接");
        enableButton.setOnClickListener(v -> setWirelessAdb(true));
        LinearLayout.LayoutParams enableParams = buttonParams();
        enableParams.topMargin = dp(20);
        root.addView(enableButton, enableParams);
        Button disable = secondaryButton("关闭无线连接");
        disable.setTextColor(RED);
        disable.setOnClickListener(v -> setWirelessAdb(false));
        LinearLayout.LayoutParams disableParams = buttonParams();
        disableParams.topMargin = dp(10);
        root.addView(disable, disableParams);

        LinearLayout smallActions = new LinearLayout(this);
        smallActions.setOrientation(LinearLayout.HORIZONTAL);
        smallActions.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams smallParams = new LinearLayout.LayoutParams(0, dp(48), 1f);
        smallParams.topMargin = dp(12);
        smallParams.rightMargin = dp(6);
        Button refresh = secondaryButton("刷新状态");
        refresh.setOnClickListener(v -> refreshStatus());
        smallActions.addView(refresh, smallParams);
        LinearLayout.LayoutParams settingsParams = new LinearLayout.LayoutParams(0, dp(48), 1f);
        settingsParams.topMargin = dp(12);
        settingsParams.leftMargin = dp(6);
        Button settings = secondaryButton("开发者选项");
        settings.setOnClickListener(v -> openDeveloperSettings());
        smallActions.addView(settings, settingsParams);
        root.addView(smallActions, matchWrap());

        TextView notice = text("安全提示：无线 ADB 会在当前局域网开放 5555 端口，并继续使用 Android 的设备授权。使用完建议点击“关闭无线连接”。", 13, MUTED, Typeface.NORMAL);
        notice.setLineSpacing(dp(3), 1f);
        LinearLayout.LayoutParams noticeParams = wrap();
        noticeParams.topMargin = dp(24);
        root.addView(notice, noticeParams);
        return scroll;
    }

    private void refreshStatus() {
        setBusy(true, "正在刷新…");
        worker.execute(() -> {
            String ip = findIpv4Address();
            String port = getProperty("service.adb.tcp.port");
            boolean wireless = port != null && !port.isEmpty() && !"-1".equals(port) && !"0".equals(port);
            String usbConfig = getProperty("sys.usb.config") + "," + getProperty("persist.sys.usb.config");
            boolean adbEnabled = usbConfig.contains("adb");
            boolean rooted = hasRoot();
            String address = ip.isEmpty() ? "" : ip + ":" + (wireless ? port : "5555");
            runOnUiThread(() -> {
                currentAddress = address;
                ipValue.setText(ip.isEmpty() ? "未连接 Wi-Fi" : ip);
                setState(portValue, wireless ? port + " · 已开启" : "已关闭", wireless ? GREEN : MUTED);
                setState(usbValue, adbEnabled ? "已开启" : "未开启", adbEnabled ? GREEN : RED);
                setState(rootValue, rooted ? "已授权" : "未授权", rooted ? GREEN : RED);
                commandValue.setText(address.isEmpty() ? "等待网络连接" : "adb connect " + address);
                enableButton.setText(wireless ? "无线连接已开启" : "开启无线连接");
                setBusy(false, null);
            });
        });
    }

    private void setWirelessAdb(boolean enabled) {
        setBusy(true, enabled ? "正在请求 Root 并开启…" : "正在关闭…");
        worker.execute(() -> {
            String command = enabled
                    ? "setprop service.adb.tcp.port 5555; stop adbd; start adbd"
                    : "setprop service.adb.tcp.port -1; stop adbd; start adbd";
            CommandResult result = runCommand(true, command);
            runOnUiThread(() -> {
                Toast.makeText(this, result.ok ? (enabled ? "无线连接已开启" : "无线连接已关闭") : "操作失败：" + result.output, Toast.LENGTH_LONG).show();
                refreshStatus();
            });
        });
    }

    private boolean hasRoot() {
        CommandResult result = runCommand(true, "id");
        return result.ok && result.output.contains("uid=0");
    }

    private String getProperty(String key) {
        CommandResult result = runCommand(false, "/system/bin/getprop " + key);
        return result.ok ? result.output.trim() : "";
    }

    private CommandResult runCommand(boolean root, String command) {
        StringBuilder output = new StringBuilder();
        try {
            ProcessBuilder builder = root ? new ProcessBuilder("su", "-c", command) : new ProcessBuilder("sh", "-c", command);
            builder.redirectErrorStream(true);
            Process process = builder.start();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (output.length() > 0) output.append('\n');
                    output.append(line);
                }
            }
            return new CommandResult(process.waitFor() == 0, output.toString());
        } catch (Exception e) {
            return new CommandResult(false, e.getMessage() == null ? "unknown error" : e.getMessage());
        }
    }

    private String findIpv4Address() {
        try {
            String fallback = "";
            for (NetworkInterface network : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                if (!network.isUp() || network.isLoopback()) continue;
                for (java.net.InetAddress address : Collections.list(network.getInetAddresses())) {
                    if (!(address instanceof Inet4Address) || address.isLoopbackAddress()) continue;
                    String value = address.getHostAddress();
                    if (value == null) continue;
                    if (network.getName().startsWith("wlan")) return value;
                    if (fallback.isEmpty()) fallback = value;
                }
            }
            return fallback;
        } catch (Exception ignored) {
            return "";
        }
    }

    private void copyCommand() {
        if (currentAddress.isEmpty()) {
            Toast.makeText(this, "手机尚未连接局域网", Toast.LENGTH_SHORT).show();
            return;
        }
        String command = "adb connect " + currentAddress;
        ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        clipboard.setPrimaryClip(ClipData.newPlainText("Scrcpy connection", command));
        Toast.makeText(this, "已复制：" + command, Toast.LENGTH_SHORT).show();
    }

    private void openDeveloperSettings() {
        try {
            startActivity(new Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS));
        } catch (Exception e) {
            startActivity(new Intent(Settings.ACTION_SETTINGS));
        }
    }

    private void setBusy(boolean busy, String label) {
        if (enableButton == null) return;
        enableButton.setEnabled(!busy);
        enableButton.setAlpha(busy ? 0.65f : 1f);
        if (busy && label != null) enableButton.setText(label);
    }

    private void setState(TextView view, String value, int color) {
        view.setText(value);
        view.setTextColor(color);
    }

    private TextView addRow(LinearLayout parent, String label, String value) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(0, dp(13), 0, dp(5));
        TextView labelView = text(label, 15, MUTED, Typeface.NORMAL);
        row.addView(labelView, new LinearLayout.LayoutParams(0, dp(36), 1f));
        TextView valueView = text(value, 15, TEXT, Typeface.BOLD);
        valueView.setGravity(Gravity.END | Gravity.CENTER_VERTICAL);
        row.addView(valueView, new LinearLayout.LayoutParams(0, dp(36), 1.35f));
        parent.addView(row, matchWrap());
        return valueView;
    }

    private LinearLayout column() {
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        return layout;
    }

    private LinearLayout card() {
        LinearLayout layout = column();
        layout.setPadding(dp(18), dp(17), dp(18), dp(17));
        layout.setBackground(rounded(SURFACE, 20, STROKE, 1));
        layout.setElevation(dp(2));
        return layout;
    }

    private LinearLayout.LayoutParams cardParams() {
        return new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
    }

    private TextView sectionTitle(String value) { return text(value, 17, TEXT, Typeface.BOLD); }

    private Button primaryButton(String value) {
        Button button = new Button(this);
        button.setText(value);
        button.setTextSize(16);
        button.setTextColor(Color.WHITE);
        button.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        button.setAllCaps(false);
        button.setGravity(Gravity.CENTER);
        button.setBackground(rounded(BLUE, 16, Color.TRANSPARENT, 0));
        button.setStateListAnimator(null);
        return button;
    }

    private Button secondaryButton(String value) {
        Button button = new Button(this);
        button.setText(value);
        button.setTextSize(14);
        button.setTextColor(TEXT);
        button.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        button.setAllCaps(false);
        button.setGravity(Gravity.CENTER);
        button.setBackground(rounded(SURFACE, 14, STROKE, 1));
        button.setStateListAnimator(null);
        return button;
    }

    private LinearLayout.LayoutParams buttonParams() { return new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(54)); }

    private TextView text(String value, int sp, int color, int style) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(sp);
        view.setTextColor(color);
        view.setTypeface(Typeface.DEFAULT, style);
        return view;
    }

    private GradientDrawable rounded(int fill, int radiusDp, int stroke, int strokeDp) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(fill);
        drawable.setCornerRadius(dp(radiusDp));
        if (strokeDp > 0) drawable.setStroke(dp(strokeDp), stroke);
        return drawable;
    }

    private LinearLayout.LayoutParams matchWrap() { return new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT); }
    private LinearLayout.LayoutParams wrap() { return new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT); }
    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }

    private void loadPalette() {
        darkMode = (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        BLUE = getColor(R.color.link_primary);
        TEXT = getColor(R.color.link_text);
        MUTED = getColor(R.color.link_muted);
        GREEN = getColor(R.color.link_success);
        RED = getColor(R.color.link_danger);
        BACKGROUND = getColor(R.color.link_background);
        SURFACE = getColor(R.color.link_surface);
        STROKE = getColor(R.color.link_stroke);
    }

    @SuppressWarnings("deprecation")
    private void applySystemBarInsets(View root) {
        root.setOnApplyWindowInsetsListener((view, insets) -> {
            view.setPadding(
                    dp(22),
                    dp(18) + insets.getSystemWindowInsetTop(),
                    dp(22),
                    dp(32) + insets.getSystemWindowInsetBottom());
            return insets;
        });
        root.requestApplyInsets();
    }

    private static final class CommandResult {
        final boolean ok;
        final String output;
        CommandResult(boolean ok, String output) { this.ok = ok; this.output = output; }
    }
}
