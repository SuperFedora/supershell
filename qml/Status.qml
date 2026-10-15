pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Consolidated system state & event-driven probes (CPU, RAM, GPU, Temp, Net, Wi-Fi, Brightness, SFX, Dock, SuperDesk, Settings).
Singleton {
    id: root

    property int cpu: 0; property int mem: 0; property int gpu: 0; property int tempC: 40
    property real netRxKbps: 0; property real netTxKbps: 0
    property string netType: "none"; property bool wifiEnabled: true; property string ssid: ""; property int signal: 0; property var wifiList: []; property var savedWifiList: []
    property real brightness: 1.0; property string idleMode: "poweroff"; property bool idleEnabled: true; property bool sfxEnabled: true
    property real spkVol: 0.6; property bool spkMuted: false; property real micVol: 1.0; property bool micMuted: false; property bool webcamEnabled: true
    property var audioSinks: []; property var audioSources: []; property var startupApps: []; property var fastfetchList: []; property var topProcs: []
    property int kbdBacklight: 0; property bool bat0Present: false; property string bat0Threshold: "Standard (0% - 100%)"; property string aiAgent: "agy"
    property bool rgbSupported: false; property int rgbCount: 0; property string rgbHex: "7aa2f7"
    property string aiReply: "Ready. Type a prompt above and press Enter for an instant answer, or click [ OPEN TERMINAL ] for an interactive session."
    property bool aiBusy: false; property string _pendingAiPrompt: ""
    property bool pocketOpen: false; property bool centerToolsOpen: false; property bool recorderOpen: false; property bool superDeckOpen: false; property string superDeckSection: "ai"; property bool superDeckPowerHighlight: false
    property bool screenRecording: false; property bool screenPaused: false; property bool settingsOpen: false; property string settingsPage: "system"
    property bool clock24h: true; property bool clockSeconds: false; property string localTz: "Local"; property bool autoTz: true
    property var worldClocks: []; property bool dnd: false; property bool sessionLocked: false
    property int notifUnread: 0; property int centerToggleSeq: 0; property var notifHistory: []; property var notifAction: null
    property bool forgeBusy: false; property bool forgeRecent: false; property string forgeState: "idle"; property int forgePct: 0; property string forgeTarget: ""; property string forgeStep: "Ready"; property string forgeLogLine: ""; property bool forgeIsolated: false; property var forgedWebApps: []; property var localApps: []; property var localAppsMap: ({})
    property string userAccount: "user@fedora"; property string userUid: "UID 1000"; property string userShell: "/bin/bash"; property string userGroups: "wheel"; property string sshStatus: "ED25519 Ready"; property string fprintStatus: "PAM Auth"
    property bool cupsActive: false; property string defaultPrinter: "None"; property int printerCount: 0; property string printerSummary: "CUPS Spooler Ready"
    property string netIface: "wlan0"; property string netIpv4: "127.0.0.1"; property string netGateway: "None"; property string netDns: "127.0.0.53"; property string firewallState: "ACTIVE"; property string vpnState: "None"
    property string diskRoot: "0G / 0G"; property string diskHome: "0G / 0G"; property int uiScale: 14; property bool animEnabled: true; property bool orcaRunning: false; property bool nightLightRunning: false; property bool touchpadEnabled: true; property bool monoAudio: false
    property var _lastCpu: null; property var _lastNet: null; property var _lastGpu: null

    FileView { id: procStat; path: "/proc/stat" }
    FileView { id: procMem; path: "/proc/meminfo" }
    FileView { id: procNet; path: "/proc/net/dev" }
    FileView { id: pkgTemp; path: "/sys/class/thermal/thermal_zone6/temp" }
    FileView { id: fallbackTemp; path: "/sys/class/thermal/thermal_zone0/temp" }
    FileView { id: gpuRc6; path: "/sys/class/drm/card1/gt/gt0/rc6_residency_ms" }
    FileView { id: sfxFile; path: Quickshell.env("HOME") + "/.config/superfedora/sfx.conf" }
    FileView { id: forgeLiveFile; path: Quickshell.env("HOME") + "/.config/superfedora/forge-live.json" }
    FileView { id: forgeRegFile; path: Quickshell.env("HOME") + "/.config/superfedora/forge.json" }

    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            const nowMs = Date.now(); procStat.reload(); const v = procStat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            if (v.length >= 4) { const idle = v[3] + (v[4] || 0), total = v.reduce((a, b) => a + b, 0); if (root._lastCpu) { const dt = total - root._lastCpu.total; root.cpu = dt > 0 ? Math.round(100 * (1 - (idle - root._lastCpu.idle) / dt)) : 0; } root._lastCpu = { total, idle }; }
            procMem.reload(); const mtext = procMem.text(), mt = mtext.match(/MemTotal:\s+(\d+)/), ma = mtext.match(/MemAvailable:\s+(\d+)/);
            if (mt && ma && Number(mt[1]) > 0) root.mem = Math.round(100 * (1 - Number(ma[1]) / Number(mt[1])));
            pkgTemp.reload(); let rawT = Number(pkgTemp.text().trim() || "0");
            if (!rawT || rawT <= 0) { fallbackTemp.reload(); rawT = Number(fallbackTemp.text().trim() || "40000"); }
            root.tempC = Math.round(rawT > 1000 ? rawT / 1000 : rawT);
            gpuRc6.reload(); const rc6Txt = gpuRc6.text().trim();
            if (rc6Txt !== "") { const rc6 = Number(rc6Txt); if (root._lastGpu && nowMs > root._lastGpu.t) root.gpu = Math.max(0, Math.min(100, Math.round(100 * (1 - Math.max(0, rc6 - root._lastGpu.rc6) / (nowMs - root._lastGpu.t))))); root._lastGpu = { rc6: rc6, t: nowMs }; }
            procNet.reload(); let rxBytes = 0, txBytes = 0;
            for (const nl of procNet.text().split("\n").slice(2)) { const parts = nl.trim().split(/[:\s]+/); if (parts.length >= 10 && parts[0] !== "lo" && parts[0] !== "") { rxBytes += Number(parts[1] || 0); txBytes += Number(parts[9] || 0); } }
            if (root._lastNet && nowMs > root._lastNet.t) { const dtSec = (nowMs - root._lastNet.t) / 1000.0; root.netRxKbps = Math.max(0, (rxBytes - root._lastNet.rx) / 1024.0 / dtSec); root.netTxKbps = Math.max(0, (txBytes - root._lastNet.tx) / 1024.0 / dtSec); }
            root._lastNet = { rx: rxBytes, tx: txBytes, t: nowMs };
        }
    }

    Process {
        id: netProc
        command: ["sh", "-c",
            "nmcli -t -f TYPE,STATE device 2>/dev/null | grep -m1 ':connected$' | cut -d: -f1 || echo none; " +
            "echo \"WFR|$(nmcli radio wifi 2>/dev/null || echo enabled)\"; " +
            "nmcli -t -f TYPE,NAME connection show 2>/dev/null | awk '/^802-11-wireless:/{sub(/^802-11-wireless:/,\"\");gsub(/\\\\:/,\":\");print \"SAV|\"$0}'; " +
            "nmcli -t -f ACTIVE,SIGNAL,SECURITY,SSID device wifi list --rescan no 2>/dev/null; " +
            "wpctl status 2>/dev/null | awk '/^Video/{exit} /Sinks:/{s=\"SNK\";next} /Sources:/{s=\"SRC\";next} /Filters:|Streams:/{s=\"\";next} s&&match($0,/(\\*?)[[:space:]]*([0-9]+)\\.[[:space:]]+([^\\[]+)/,m){n=m[3];sub(/[[:space:]]+$/,\"\",n);sub(/^.*Audio[[:space:]]+/,\"\",n);sub(/[[:space:]]*Output.*$/,\"\",n);sub(/HDMI \\/ DisplayPort/,\"HDMI/DP\",n);sub(/Microphone/,\"Mic\",n);print s\"|\"m[2]\"|\"((m[1]==\"*\")?1:0)\"|\"n}'; " +
            "b=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'); echo \"BRI|${b:-100}\"; " +
            "echo \"SPK|$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)\"; echo \"MIC|$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)\"; " +
            "echo \"CAM|$(cat ~/.config/superfedora/webcam-enabled 2>/dev/null || echo on)\"; " +
            "~/.config/hypr/scripts/toggle-touchpad.sh dpms sync >/dev/null 2>&1 || true; k=$(cat /sys/class/leds/tpacpi::kbd_backlight/brightness ~/.config/superfedora/kbd-backlight 2>/dev/null | head -n1); echo \"KBD|${k:-0}\"; " +
            "ag=$(grep '^AI_AGENT=' ~/.config/superfedora/quake-ai.env 2>/dev/null | cut -d= -f2 | tr -d \"'\\\"\"); echo \"AGY|${ag:-agy}\"; " +
            "awk -F'=' '/^[[:space:]]*exec-once[[:space:]]*=/{c=$2; sub(/^[[:space:]]+/,\"\",c); if(c!~/(systemctl|superfedora\\.locked|hyprpolkitagent|sfx play startup)/) print \"STA|\"c}' ~/.config/hypr/conf/autostart.conf 2>/dev/null || true; " +
            "(fastfetch -s OS:Host:Kernel:Uptime:WM:CPU:GPU:Memory:Disk:LocalIP --logo none --pipe true 2>/dev/null || printf 'OS: Fedora Linux\\nKernel: %s\\n' \"$(uname -sr)\") | awk -F': ' 'NF>=2{print \"FF|\"$1\"|\"substr($0,index($0,\": \")+2)}'; " +
            "ps -eo pid,pcpu,pmem,comm --sort=-pcpu --no-headers 2>/dev/null | head -n 7 | awk '{c=$4; for(i=5;i<=NF;i++) c=c\" \"$i; printf \"PRC|%s|%s|%s|%s\\n\",$1,$2,$3,c}'; " +
            "echo \"RGB|$(cat ~/.config/superfedora/rgb-devices 2>/dev/null || echo 0)|$(cat ~/.config/superfedora/rgb-color 2>/dev/null || echo 7aa2f7)\"; " +
            "if pgrep -x wf-recorder >/dev/null || pgrep -f '^gpu-screen-recorder' >/dev/null; then [ -f ~/.config/superfedora/recording-paused ] && echo 'REC|1|1' || echo 'REC|1|0'; else rm -f ~/.config/superfedora/recording-paused; echo 'REC|0|0'; fi; " +
            "if [ -d /sys/class/power_supply/BAT0 ]; then bs=$(cat /sys/class/power_supply/BAT0/charge_control_start_threshold /sys/class/power_supply/BAT0/charge_start_threshold 2>/dev/null | head -n1); be=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold /sys/class/power_supply/BAT0/charge_stop_threshold 2>/dev/null | head -n1); echo \"BAT0|1|${bs:-0}|${be:-100}\"; fi; " +
            "(~/.local/bin/supersettings probe 2>/dev/null || ~/.local/bin/sf settings-probe 2>/dev/null || true); " +
            "for f in ~/.local/share/applications/*.desktop; do [ -f \"$f\" ] || continue; id=$(basename \"$f\" .desktop); nm=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); ic=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-); ex=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/ %[a-zA-Z]//g'); wm=$(grep -m1 '^StartupWMClass=' \"$f\" | cut -d= -f2-); nd=$(grep -m1 '^NoDisplay=' \"$f\" | cut -d= -f2-); [ \"$nd\" = \"true\" ] || printf 'APP|%s|%s|%s|%s|%s\\n' \"$id\" \"$nm\" \"$ic\" \"$ex\" \"$wm\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n"), type = lines[0] || "none", byName = {}, list = [], saved = [], sinks = [], sources = [], stApps = [], ff = [], procs = [], lApps = [], lMap = {};
                let activeSsid = "", activeSig = 0;
                for (let i = 1; i < lines.length; i++) {
                    if (lines[i].startsWith("WFR|")) { root.wifiEnabled = (lines[i].split("|")[1] || "enabled").trim() !== "disabled"; continue; }
                    if (lines[i].startsWith("SAV|")) { const sv = lines[i].slice(4).trim(); if (sv && saved.indexOf(sv) === -1) saved.push(sv); continue; }
                    if (lines[i].startsWith("SNK|") || lines[i].startsWith("SRC|")) { const p = lines[i].split("|"), arr = (p[0] === "SNK" ? sinks : sources); if (arr.length < 6 || p[2] === "1") arr.push({ id: p[1], active: p[2] === "1", name: p.slice(3).join("|") }); continue; }
                    if (lines[i].startsWith("BRI|")) { const bv = Number(lines[i].split("|")[1] || 100); if (!isNaN(bv) && bv > 0) root.brightness = Math.max(0.05, Math.min(1.0, bv / 100.0)); continue; }
                    if (lines[i].startsWith("SPK|")) { const sm = lines[i].match(/Volume:\s*([0-9.]+)/); if (sm) root.spkVol = Math.max(0, Math.min(1, Number(sm[1]))); root.spkMuted = lines[i].includes("[MUTED]"); continue; }
                    if (lines[i].startsWith("MIC|")) { const mm = lines[i].match(/Volume:\s*([0-9.]+)/); if (mm) root.micVol = Math.max(0, Math.min(1, Number(mm[1]))); root.micMuted = lines[i].includes("[MUTED]"); continue; }
                    if (lines[i].startsWith("CAM|")) { const cv = (lines[i].split("|")[1] || "on").trim().toLowerCase(); root.webcamEnabled = (cv !== "off" && cv !== "0" && cv !== "false"); continue; }
                    if (lines[i].startsWith("KBD|")) { root.kbdBacklight = Math.max(0, Math.min(2, Number(lines[i].split("|")[1] || 0))); continue; }
                    if (lines[i].startsWith("AGY|")) { root.aiAgent = (lines[i].split("|")[1] || "agy").trim(); continue; }
                    if (lines[i].startsWith("STA|")) { const sc = lines[i].slice(4).trim(); if (sc) stApps.push(sc); continue; }
                    if (lines[i].startsWith("FF|")) { const fp = lines[i].split("|"); if (fp.length >= 3) ff.push({ k: fp[1], v: fp.slice(2).join("|") }); continue; }
                    if (lines[i].startsWith("PRC|")) { const pp = lines[i].split("|"); if (pp.length >= 5) procs.push({ pid: pp[1], cpu: pp[2], mem: pp[3], cmd: pp[4] }); continue; }
                    if (lines[i].startsWith("RGB|")) { const rp = lines[i].split("|"); root.rgbCount = Number(rp[1] || 0); root.rgbSupported = root.rgbCount > 0; root.rgbHex = (rp[2] || "7aa2f7").replace(/^#/, ""); continue; }
                    if (lines[i].startsWith("REC|")) { const rc = lines[i].split("|"), rec = (rc[1] || "0").trim() === "1"; if (root.screenRecording && !rec) root.recorderOpen = false; root.screenRecording = rec; root.screenPaused = (rc[2] || "0").trim() === "1"; if (rec) root.recorderOpen = true; continue; }
                    if (lines[i].startsWith("BAT0|")) { const bp = lines[i].split("|"); root.bat0Present = true; root.bat0Threshold = "Start " + (bp[2] || "0") + "% / Stop " + (bp[3] || "100") + "%"; continue; }
                    if (lines[i].startsWith("USR|")) { const up = lines[i].split("|"); root.userAccount = up[1] || "user@fedora"; root.userUid = up[2] || "UID 1000"; root.userShell = up[3] || "/bin/bash"; root.userGroups = up[4] || "wheel"; root.sshStatus = up[5] || "SSH"; root.fprintStatus = up[6] || "PAM"; continue; }
                    if (lines[i].startsWith("PRN|")) { const pr = lines[i].split("|"); root.cupsActive = pr[1] === "1"; root.defaultPrinter = pr[2] || "None"; root.printerCount = Number(pr[3] || 0); root.printerSummary = pr[4] || "CUPS Spooler"; continue; }
                    if (lines[i].startsWith("NETI|")) { const ni = lines[i].split("|"); root.netIface = ni[1] || "wlan0"; root.netIpv4 = ni[2] || "Disconnected"; root.netGateway = ni[3] || "None"; root.netDns = ni[4] || "127.0.0.53"; root.firewallState = ni[5] || "ACTIVE"; root.vpnState = ni[6] || "None"; continue; }
                    if (lines[i].startsWith("DSK|")) { const dk = lines[i].split("|"); root.diskRoot = dk[1] || "0G"; root.diskHome = dk[2] || "0G"; continue; }
                    if (lines[i].startsWith("A11Y|")) { const ay = lines[i].split("|"); root.uiScale = Number(ay[1] || 14); root.animEnabled = ay[2] !== "0"; root.orcaRunning = ay[3] === "1"; root.nightLightRunning = ay[4] === "1"; root.touchpadEnabled = ay[5] !== "0"; root.monoAudio = ay[6] === "1"; continue; }
                    if (lines[i].startsWith("APP|")) { const ap = lines[i].split("|"); if (ap.length >= 5 && ap[1] && ap[2]) { const iconPath = ap[3].startsWith("/") ? ap[3] : (Quickshell.env("HOME") + "/.local/share/icons/hicolor/128x128/apps/" + ap[3] + ".png"), obj = { id: ap[1], name: ap[2], icon: iconPath, execCmd: ap[4], wmClass: ap[5] || ap[1], execute: function() { Quickshell.execDetached(["sh", "-c", ap[4]]); } }; lApps.push(obj); lMap[ap[1].toLowerCase()] = obj; if (ap[5]) lMap[ap[5].toLowerCase()] = obj; } continue; }
                    const parts = lines[i].split(":"); if (parts.length < 4) continue;
                    const act = parts[0] === "yes", sig = Number(parts[1] || 0), sec = (parts[2] || "").trim(), name = parts.slice(3).join(":").replace(/\\:/g, ":").replace(/\\\\/g, "\\").trim(), open = (!sec || sec === "--");
                    if (!name) continue;
                    if (act) { activeSsid = name; activeSig = sig; }
                    if (byName[name]) { if (act) byName[name].active = true; if (sig > byName[name].signal) byName[name].signal = sig; }
                    else if (list.length < 8 || act) { const item = { ssid: name, signal: sig, active: act, open: open, security: open ? "OPEN" : "WPA", saved: saved.indexOf(name) !== -1 }; byName[name] = item; list.push(item); }
                }
                list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
                root.savedWifiList = saved; root.audioSinks = sinks; root.audioSources = sources; root.startupApps = stApps; root.fastfetchList = ff; root.topProcs = procs; root.localApps = lApps; root.localAppsMap = lMap;
                root.wifiList = list.slice(0, 8); root.netType = (type === "wifi" || type === "ethernet") ? type : "none";
                root.signal = type === "wifi" ? activeSig : 0; root.ssid = type === "wifi" ? activeSsid : "";
            }
        }
    }

    Process { id: rgbProbeProc; command: ["sh", "-c", "mkdir -p ~/.config/superfedora; c=0; if command -v openrgb >/dev/null 2>&1; then c=$(timeout 3 openrgb --noautoconnect -l 2>/dev/null | grep -cE '^[0-9]+: ' || true); fi; [ \"$c\" -gt 0 ] && echo \"$c\" > ~/.config/superfedora/rgb-devices || rm -f ~/.config/superfedora/rgb-devices; qs ipc call status refresh >/dev/null 2>&1 || true"] }
    Process { id: forgeTailProc; command: ["sh", "-c", "tail -n 8 ~/.cache/superfedora/forge-build/forge.log 2>/dev/null | awk 'NF{line=$0} END{print substr(line,1,96)}'"]; stdout: StdioCollector { onStreamFinished: { const l = text.trim(); if (l) root.forgeLogLine = l; } } }
    Process { id: aiAskProc; command: ["sh", "-c", "~/.config/hypr/scripts/quake-ai.sh ask " + JSON.stringify(root._pendingAiPrompt)]; stdout: StdioCollector { onStreamFinished: { root.aiReply = text.trim() || "Done."; root.aiBusy = false; } } }
    Process { id: tzProc; command: ["sh", "-c", "mkdir -p ~/.config/superfedora; f=~/.config/superfedora/clock.conf; [ -f \"$f\" ] && . \"$f\"; w=~/.config/superfedora/world-clocks.txt; [ -f \"$w\" ] || printf 'UTC\\nAmerica/New_York\\nAmerica/Los_Angeles\\nEurope/London\\n' > \"$w\"; c24=\"${CLOCK_24H:-1}\"; csec=\"${CLOCK_SECONDS:-0}\"; tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo Local); abbr=$(date +%Z); auto=$(gsettings get org.gnome.desktop.datetime automatic-timezone 2>/dev/null || echo true); echo \"CFG|$c24|$csec|$tz ($abbr)|$auto\"; fmt=$([ \"$c24\" = \"1\" ] && echo '%a %H:%M' || echo '%a %I:%M %p'); while IFS= read -r z; do [ -n \"$z\" ] && printf 'WC|%s|%s\\n' \"$z\" \"$(TZ=\"$z\" date +\"$fmt\")\"; done < \"$w\""]; stdout: StdioCollector { onStreamFinished: { const wc = []; for (const line of text.trim().split("\n")) { const p = line.split("|"); if (p[0] === "CFG") { root.clock24h = p[1] !== "0"; root.clockSeconds = p[2] === "1"; root.localTz = p[3] || "Local"; root.autoTz = p[4] === "true"; } else if (p[0] === "WC" && p.length >= 3) wc.push({ tz: p[1], time: p[2] }); } root.worldClocks = wc; } } }

    function reloadForge() {
        forgeLiveFile.reload(); const lraw = forgeLiveFile.text().trim();
        if (lraw) { try { const d = JSON.parse(lraw), ts = Number(d.ts || 0), age = (Date.now() / 1000) - ts; if (!(root.forgeBusy && ts < root._forgeStartTs - 1)) { root.forgeBusy = Boolean(d.active) && age < 180; root.forgeRecent = !root.forgeBusy && age >= 0 && age < 8 && d.state !== "idle"; root.forgeState = String(d.state || "idle"); root.forgePct = Number(d.pct || 0); root.forgeTarget = String(d.target || ""); root.forgeStep = String(d.step || "Ready"); } } catch (e) {} }
        forgeRegFile.reload(); const rraw = forgeRegFile.text().trim();
        if (rraw) {
            try {
                const r = JSON.parse(rraw), wa = [], tg = (r && r.targets) ? r.targets : {}, nextMap = Object.assign({}, root.localAppsMap || {}), nextApps = (root.localApps || []).filter(a => !String(a.id || "").startsWith("sf-webapp-"));
                for (const k in nextMap) if (k.startsWith("sf-webapp-")) delete nextMap[k];
                for (const k in tg) if (tg[k] && tg[k].type === "webapp") { const aid = tg[k].app_id || ("sf-webapp-" + k), nm = tg[k].name || k, bin = tg[k].binary || (Quickshell.env("HOME") + "/.local/bin/" + aid), ic = tg[k].icon || (Quickshell.env("HOME") + "/.local/share/icons/hicolor/256x256/apps/" + aid + ".png"), obj = { id: aid, name: nm, icon: ic, execCmd: bin, wmClass: aid, execute: function() { Quickshell.execDetached(["sh", "-c", "'" + bin + "'"]); } }; wa.push({ slug: k, app_id: aid, name: nm, url: tg[k].url || "", mode: tg[k].profile || "shared", bin: bin, icon: ic }); nextApps.push(obj); nextMap[aid.toLowerCase()] = obj; }
                root.forgedWebApps = wa; root.localApps = nextApps; root.localAppsMap = nextMap;
            } catch (e) {}
        }
        root.reloadDock();
    }
    property real _forgeStartTs: 0
    function runForge(target) {
        const q = String(target || "").trim().replace(/['"]/g, ""); if (!q || root.forgeBusy) return;
        const flag = root.forgeIsolated ? "--isolated " : "--shared ";
        root._forgeStartTs = Date.now() / 1000; root.forgeBusy = true; root.forgeRecent = false; root.forgeState = "working"; root.forgePct = 5; root.forgeTarget = q; root.forgeStep = "Initializing Forge..."; root.forgeLogLine = ""; root.playSfx("confirm");
        Quickshell.execDetached(["sh", "-c", "~/.local/bin/superforge " + flag + "'" + q + "' || ~/.local/bin/sf forge " + flag + "'" + q + "'"]);
    }
    function stopForge() { root._forgeStartTs = 0; root.forgeBusy = false; root.forgeRecent = false; root.forgeState = "idle"; root.forgePct = 0; root.forgeStep = "Ready"; root.playSfx("click"); Quickshell.execDetached(["sh", "-c", "pkill -f 'superforge|forge-runner\\.sh|forge\\.sh|forge-webapp\\.py' 2>/dev/null || true; printf '{\"active\":false,\"state\":\"idle\",\"target\":\"\",\"pct\":0,\"step\":\"Ready\",\"ts\":0}\\n' > ~/.config/superfedora/forge-live.json"]); }
    function dismissForgeBanner() { root.forgeRecent = false; root.forgeState = "idle"; Quickshell.execDetached(["sh", "-c", "printf '{\"active\":false,\"state\":\"idle\",\"target\":\"\",\"pct\":0,\"step\":\"Ready\",\"ts\":0}\\n' > ~/.config/superfedora/forge-live.json"]); }
    function removeForge(slug) { const s = String(slug || "").trim().replace(/['"]/g, ""); if (!s) return; root.playSfx("click"); Quickshell.execDetached(["sh", "-c", "~/.local/bin/superforge remove '" + s + "' || ~/.local/bin/sf forge remove '" + s + "'"]); }
    function setRgbColor(hex) { if (!root.rgbSupported) return; const h = String(hex || "7aa2f7").replace(/^#/, ""); root.rgbHex = h === "off" ? "000000" : h; root.playSfx("click"); Quickshell.execDetached(["sh", "-c", "~/.local/bin/supertheme rgb '" + h + "' || ~/.local/bin/sf theme rgb '" + h + "'"]); }
    function askQuickAi(prompt) { const q = String(prompt || "").trim(); if (!q || root.aiBusy) return; root._pendingAiPrompt = q; root.aiBusy = true; root.aiReply = "Querying " + root.aiAgent.toUpperCase() + "..."; root.playSfx("confirm"); aiAskProc.running = true; }
    function addStartupApp(cmd) { const c = String(cmd || "").trim().replace(/'/g, ""); if (!c) return; root.playSfx("confirm"); Quickshell.execDetached(["sh", "-c", "grep -Fqx 'exec-once = " + c + "' ~/.config/hypr/conf/autostart.conf 2>/dev/null || printf '\\nexec-once = %s\\n' '" + c + "' >> ~/.config/hypr/conf/autostart.conf; [ -f ~/Projects/superfedora/superfedora/dotfiles/.config/hypr/conf/autostart.conf ] && cp -f ~/.config/hypr/conf/autostart.conf ~/Projects/superfedora/superfedora/dotfiles/.config/hypr/conf/autostart.conf; qs ipc call status refresh"]); }
    function removeStartupApp(cmd) { const c = String(cmd || "").trim().replace(/'/g, ""); if (!c) return; root.playSfx("click"); Quickshell.execDetached(["sh", "-c", "awk -v t='exec-once = " + c + "' '$0 != t' ~/.config/hypr/conf/autostart.conf > ~/.config/hypr/conf/autostart.conf.tmp && mv ~/.config/hypr/conf/autostart.conf.tmp ~/.config/hypr/conf/autostart.conf; [ -f ~/Projects/superfedora/superfedora/dotfiles/.config/hypr/conf/autostart.conf ] && cp -f ~/.config/hypr/conf/autostart.conf ~/Projects/superfedora/superfedora/dotfiles/.config/hypr/conf/autostart.conf; qs ipc call status refresh"]); }
    function saveClockPrefs(use24h, showSec) { root.clock24h = use24h; root.clockSeconds = showSec; Quickshell.execDetached(["sh", "-c", "mkdir -p ~/.config/superfedora && printf 'CLOCK_24H=%s\\nCLOCK_SECONDS=%s\\n' " + (use24h ? "1" : "0") + " " + (showSec ? "1" : "0") + " > ~/.config/superfedora/clock.conf"]); tzProc.running = true; }
    function setBrightness(val) { const c = Math.max(0.05, Math.min(1.0, val)); root.brightness = c; Quickshell.execDetached(["sh", "-c", "brightnessctl -e4 -n2 set " + Math.round(c * 100) + "% >/dev/null 2>&1 || true"]); }
    function reloadSfx() { sfxFile.reload(); root.sfxEnabled = !sfxFile.text().trim().includes("SFX_ENABLED=0"); }
    function reloadWebcam() { netProc.running = true; }
    function playSfx(name) { if (root.sfxEnabled) Quickshell.execDetached(["sh", "-c", "(~/.local/bin/supertheme sfx play " + name + " || ~/.local/bin/sf sfx play " + name + ") >/dev/null 2>&1"]); }
    function toggleSfx() { root.sfxEnabled = !root.sfxEnabled; Quickshell.execDetached(["sh", "-c", "(~/.local/bin/supertheme sfx toggle || ~/.local/bin/sf sfx toggle) >/dev/null 2>&1"]); }
    function toggleWifiRadio(en) { const next = (typeof en === "boolean") ? en : !root.wifiEnabled; root.wifiEnabled = next; if (!next && root.netType === "wifi") { root.netType = "none"; root.ssid = ""; root.signal = 0; root.wifiList = []; } root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "nmcli radio wifi " + (next ? "on" : "off") + "; sleep 0.5 && qs ipc call status refresh >/dev/null 2>&1 || true"]); }
    function toggleSpeakerMute(m) { const next = (typeof m === "boolean") ? m : !root.spkMuted; root.spkMuted = next; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/toggle-touchpad.sh speaker " + (next ? "mute" : "unmute")]); }
    function setSpeakerVolume(val) { const c = Math.max(0, Math.min(1, val)); root.spkVol = c; Quickshell.execDetached(["sh", "-c", "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + Math.round(c * 100) + "%"]); }
    function toggleMicMute(m) { const next = (typeof m === "boolean") ? m : !root.micMuted; root.micMuted = next; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/toggle-touchpad.sh mic " + (next ? "mute" : "unmute")]); }
    function setMicVolume(val) { const c = Math.max(0, Math.min(1, val)); root.micVol = c; Quickshell.execDetached(["sh", "-c", "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SOURCE@ " + Math.round(c * 100) + "%"]); }
    function setAudioDefault(id) { const sid = String(id); if (root.audioSinks.some(s => s.id === sid)) root.audioSinks = root.audioSinks.map(s => ({ id: s.id, active: s.id === sid, name: s.name })); if (root.audioSources.some(s => s.id === sid)) root.audioSources = root.audioSources.map(s => ({ id: s.id, active: s.id === sid, name: s.name })); root.playSfx("click"); Quickshell.execDetached(["sh", "-c", "wpctl set-default " + sid + "; sleep 0.2 && qs ipc call status refresh >/dev/null 2>&1 || true"]); }
    function toggleWebcam() { root.webcamEnabled = !root.webcamEnabled; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/toggle-touchpad.sh webcam " + (root.webcamEnabled ? "on" : "off")]); }
    function setKbdBacklight(lvl) { const next = (typeof lvl === "number") ? Math.max(0, Math.min(2, lvl)) : ((root.kbdBacklight + 1) % 3); root.kbdBacklight = next; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/toggle-touchpad.sh kbd-backlight " + next]); }
    function selectAiAgent(id) { root.aiAgent = id; root.playSfx("click"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/quake-ai.sh select-agent '" + id + "'"]); }
    function nextAiAgent() { const ids = ["agy", "mcode", "grok", "vibe", "claude", "chatgpt", "ollama"]; root.selectAiAgent(ids[(ids.indexOf(root.aiAgent) + 1) % ids.length]); }

    function normalizeDeckTab(sec) {
        const s = String(sec || "").toLowerCase();
        if (s === "`" || s === "grave" || s === "tilde" || s === "ai" || s === "harness" || s === "agent") return "ai";
        if (s === "sys" || s === "btop" || s === "fastfetch" || s === "vitals" || s === "monitor" || s === "1") return "sys";
        if (s === "wifi" || s === "network" || s === "net" || s === "wlan" || s === "2") return "wifi"; if (s === "bluetooth" || s === "bt" || s === "devices" || s === "3") return "bluetooth";
        if (s === "audio" || s === "sound" || s === "sensors" || s === "cam" || s === "mic" || s === "speaker" || s === "io" || s === "zerotrust" || s === "4") return "audio";
        if (s === "display" || s === "displays" || s === "screen" || s === "kbd" || s === "input" || s === "5") return "display"; if (s === "theme" || s === "personalization" || s === "appearance" || s === "surface" || s === "6") return "theme";
        if (s === "shell" || s === "windowing" || s === "multitasking" || s === "bar" || s === "dock" || s === "7") return "shell"; if (s === "forge" || s === "apps" || s === "software" || s === "build" || s === "8") return "forge";
        if (s === "state" || s === "snapshots" || s === "btrfs" || s === "system" || s === "9") return "state";
        return (s === "power" || s === "battery" || s === "session" || s === "0" || s === "10") ? "power" : (root.superDeckSection || "ai");
    }
    function normalizeSettingsPage(p) {
        const s = String(p || "").toLowerCase();
        if (s === "system" || s === "sys" || s === "display" || s === "displays" || s === "audio" || s === "sound" || s === "1" || s === "4" || s === "5") return "system";
        if (s === "devices" || s === "bluetooth" || s === "bt" || s === "printers" || s === "printer" || s === "input" || s === "keyboard" || s === "mouse" || s === "3") return "devices";
        if (s === "network" || s === "net" || s === "wifi" || s === "2") return "network";
        if (s === "personalization" || s === "theme" || s === "appearance" || s === "6") return "personalization";
        if (s === "windowing" || s === "shell" || s === "multitasking" || s === "dock" || s === "bar" || s === "7") return "windowing";
        if (s === "notifications" || s === "notifs" || s === "banners" || s === "clock") return "notifications";
        if (s === "apps" || s === "forge" || s === "startup" || s === "autostart" || s === "8") return "apps";
        if (s === "accounts" || s === "users" || s === "user") return "accounts";
        if (s === "accessibility" || s === "a11y" || s === "acc") return "accessibility";
        if (s === "power" || s === "state" || s === "ai" || s === "updates" || s === "recovery" || s === "`" || s === "9" || s === "0") return "power";
        return root.settingsPage || "system";
    }
    property bool _quakeShown: false
    function syncQuakeAi(hdrH) { const want = root.superDeckOpen && root.normalizeDeckTab(root.superDeckSection) === "ai"; if (!want && !root._quakeShown) return; root._quakeShown = want; Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/quake-ai.sh " + (want ? ("show " + (hdrH || 40)) : "hide keep-deck") + " >/dev/null 2>&1"]); }
    onSuperDeckOpenChanged: { if (root.superDeckOpen) { root.settingsOpen = false; root.appGridOpen = false; root.recorderOpen = false; root.centerToolsOpen = false; root.pocketOpen = false; } root.syncQuakeAi(); }
    onSuperDeckSectionChanged: if (root.superDeckOpen) root.syncQuakeAi()
    onAppGridOpenChanged: if (root.appGridOpen) { root.superDeckOpen = false; root.settingsOpen = false; root.recorderOpen = false; }
    onRecorderOpenChanged: if (root.recorderOpen) { root.superDeckOpen = false; root.settingsOpen = false; root.appGridOpen = false; }
    onSettingsOpenChanged: if (root.settingsOpen) { root.superDeckOpen = false; root.appGridOpen = false; root.recorderOpen = false; }
    function openSettings(page) { root.superDeckOpen = false; if (page) root.settingsPage = root.normalizeSettingsPage(page); root.settingsOpen = true; root.refresh(); root.playSfx("click"); }
    function toggleSettings(page) { if (!page) { root.superDeckOpen = false; root.settingsOpen = !root.settingsOpen; } else { const p = root.normalizeSettingsPage(page); if (root.settingsOpen && root.settingsPage === p) root.settingsOpen = false; else { root.superDeckOpen = false; root.settingsPage = p; root.settingsOpen = true; } } if (root.settingsOpen) root.refresh(); root.playSfx("click"); }
    function toggleSuperDeck(sec) { const t = (!sec || sec === "last") ? root.normalizeDeckTab(root.superDeckSection) : root.normalizeDeckTab(sec), wasOpen = root.superDeckOpen, prev = root.superDeckSection; root.settingsOpen = false; root.appGridOpen = false; root.recorderOpen = false; root.superDeckPowerHighlight = (t === "power"); root.superDeckSection = t; root.superDeckOpen = true; if (wasOpen && prev === t) root.syncQuakeAi(); root.refresh(); root.playSfx("click"); }
    function toggleIdle() { root.idleMode = root.idleMode === "poweroff" ? "lock" : (root.idleMode === "lock" ? "screensaver" : "poweroff"); root.idleEnabled = root.idleMode === "poweroff"; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/toggle-idle.sh " + root.idleMode]); }
    function startScreenRecord(region) { root.superDeckOpen = false; root.recorderOpen = !region; root.screenRecording = !region; root.screenPaused = false; root.playSfx("confirm"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/screenshot.sh " + (region ? "record-region" : "record")]); }
    function pauseScreenRecord() { root.screenPaused = !root.screenPaused; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/screenshot.sh record-pause"]); }
    function stopScreenRecord() { root.screenRecording = false; root.screenPaused = false; root.recorderOpen = false; root.playSfx("click"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/screenshot.sh record-stop"]); }
    Process { id: idleProc; command: ["sh", "-c", "cat ~/.config/superfedora/idle-mode 2>/dev/null || ([ -f ~/.config/superfedora/stay-awake ] && echo screensaver || echo poweroff)"]; stdout: StdioCollector { onStreamFinished: { const m = text.trim(); root.idleMode = (m === "lock" || m === "screensaver") ? m : "poweroff"; root.idleEnabled = root.idleMode === "poweroff"; } } }
    property bool appGridOpen: false; property var clients: []; property var wsModes: ({}); property string defaultWsMode: "dwindle"
    property var dockConfig: ({ position: "bottom", autohide: false, showAlways: true, opacity: 1.0, pinned: ["kitty", "org.mozilla.firefox", "com.google.Chrome", "org.gnome.Nautilus", "nvim", "btop"] })
    readonly property var defaultBarIcons: ["wifi", "bluetooth", "|", "speaker", "mic", "camera", "|", "battery", "power"]
    readonly property var coreBarIcons: ["wifi", "bluetooth", "speaker", "mic", "camera", "battery", "power"]
    property var barIcons: ["wifi", "bluetooth", "|", "speaker", "mic", "camera", "|", "battery", "power"]; property var barHiddenIcons: []
    FileView { id: dockFile; path: Quickshell.env("HOME") + "/.config/superfedora/dock.json" }
    FileView { id: modesFile; path: Quickshell.env("HOME") + "/.config/superfedora/workspace-modes.json" }
    FileView { id: barIconsFile; path: Quickshell.env("HOME") + "/.config/superfedora/bar-icons.json" }
    function reloadBarIcons(): void { barIconsFile.reload(); const raw = barIconsFile.text().trim(); if (!raw) return; try { const d = JSON.parse(raw), seen = {}, out = []; if (d && Array.isArray(d.order)) { for (const id of d.order) { if (id === "|") out.push("|"); else if (root.coreBarIcons.indexOf(id) !== -1 && !seen[id]) { seen[id] = true; out.push(id); } } for (const id of root.coreBarIcons) if (!seen[id]) out.push(id); root.barIcons = out; } if (d && Array.isArray(d.hidden)) root.barHiddenIcons = d.hidden.filter(id => root.coreBarIcons.indexOf(id) !== -1); } catch (e) {} }
    function saveBarIcons(): void { Quickshell.execDetached(["sh", "-c", "mkdir -p ~/.config/superfedora && printf '%s\\n' '" + JSON.stringify({ order: root.barIcons, hidden: root.barHiddenIcons }) + "' > ~/.config/superfedora/bar-icons.json"]); }
    function swapBarIcons(fromIdx, toIdx): void { const arr = root.barIcons.slice(); if (fromIdx < 0 || toIdx < 0 || fromIdx >= arr.length || toIdx >= arr.length || fromIdx === toIdx) return; const tmp = arr[fromIdx]; arr[fromIdx] = arr[toIdx]; arr[toIdx] = tmp; root.barIcons = arr; root.playSfx("click"); root.saveBarIcons(); }
    function moveBarIcon(id, dir): void { const arr = root.barIcons.slice(), idx = arr.indexOf(id), step = dir < 0 ? -1 : 1; if (idx < 0) return; let t = idx + step; while (t >= 0 && t < arr.length && arr[t] === "|") t += step; if (t >= 0 && t < arr.length) root.swapBarIcons(idx, t); }
    function toggleBarIconHidden(id): void { if (!id || id === "|" || root.coreBarIcons.indexOf(id) === -1) return; const h = root.barHiddenIcons.slice(), i = h.indexOf(id); if (i >= 0) h.splice(i, 1); else h.push(id); root.barHiddenIcons = h; root.playSfx("toggle"); root.saveBarIcons(); }
    function toggleBarDividers(): void { if (root.barIcons.indexOf("|") !== -1) root.barIcons = root.barIcons.filter(x => x !== "|"); else { const c = root.barIcons.filter(x => x !== "|"); root.barIcons = [c[0], c[1], "|", c[2], c[3], c[4], "|", c[5], c[6]].filter(Boolean); } root.playSfx("toggle"); root.saveBarIcons(); }
    function resetBarIcons(): void { root.barIcons = root.defaultBarIcons.slice(); root.barHiddenIcons = []; root.playSfx("toggle"); root.saveBarIcons(); }
    function reloadDock(): void { dockFile.reload(); const raw = dockFile.text().trim(); if (raw) { try { const d = JSON.parse(raw); if (d && typeof d === "object") root.dockConfig = d; } catch (e) {} } modesFile.reload(); const mraw = modesFile.text().trim(); if (mraw) { try { const m = JSON.parse(mraw); if (m && m.workspaces) root.wsModes = m.workspaces; if (m && m.default) root.defaultWsMode = m.default; } catch (e) {} } }
    function wsModeFor(wsId): string { const k = String(wsId); return (root.wsModes && root.wsModes[k]) ? root.wsModes[k] : root.defaultWsMode; }
    function runDockCmd(args): void { Quickshell.execDetached(["sh", "-c", "~/.local/bin/superdock " + args + " 2>/dev/null || ~/.local/bin/superfedora dock " + args]); }
    Process { id: clientsProc; command: ["sh", "-c", "hyprctl clients -j 2>/dev/null || echo '[]'"]; stdout: StdioCollector { onStreamFinished: { try { const arr = JSON.parse(text.trim() || "[]"); root.clients = arr.filter(c => c.mapped && c.workspace && (c.workspace.id > 0 || String(c.workspace.name || "").includes("minimized"))); } catch (e) {} } } }
    Connections { target: Hyprland; function onRawEvent(event) { const n = String(event.name || ""); if (n.includes("window") || n.includes("workspace") || n.includes("focusedmon")) clientsProc.running = true; if (n === "closewindow" && root.superDeckOpen && root._quakeShown && root.normalizeDeckTab(root.superDeckSection) === "ai") Quickshell.execDetached(["sh", "-c", "sleep 0.1; hyprctl clients -j 2>/dev/null | grep -q '\"class\": \"quake-ai\"' || ~/.config/hypr/scripts/quake-ai.sh hide >/dev/null 2>&1"]); } }
    Component.onCompleted: { root.reloadBarIcons(); root.reloadForge(); root.reloadSfx(); root.reloadWebcam(); clientsProc.running = true; rgbProbeProc.running = true; }
    IpcHandler { target: "dock"; function reload(): void { root.reloadForge(); clientsProc.running = true; } function toggleApps(): void { root.appGridOpen = !root.appGridOpen; root.playSfx("click"); } function toggle(): void { root.runDockCmd("always toggle"); } }
    IpcHandler { target: "superdeck"; function toggle(): void { root.toggleSuperDeck(""); } function toggleAi(): void { root.toggleSuperDeck("ai"); } function open(sec: string): void { root.toggleSuperDeck(sec); } function numkey(n: string): void { if (root.superDeckOpen) root.toggleSuperDeck(n); else Hyprland.dispatch("workspace " + (n === "0" ? "empty" : n)); } function close(): void { root.superDeckOpen = false; } }
    IpcHandler { target: "settings"; function toggle(): void { root.toggleSettings(""); } function open(page: string): void { root.openSettings(page); } function close(): void { root.settingsOpen = false; } }
    IpcHandler { target: "panels"; function settings(): void { root.toggleSettings(""); } }
    IpcHandler { target: "status"; function refresh(): void { root.refresh(); } function reloadBar(): void { root.reloadBarIcons(); } function reloadForge(): void { root.reloadForge(); } }
    Timer { interval: 500; running: root.forgeBusy || root.forgeRecent; repeat: true; onTriggered: { root.reloadForge(); if (root.forgeBusy) forgeTailProc.running = true; } }
    Timer { interval: 4500; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    function refresh() { netProc.running = true; idleProc.running = true; tzProc.running = true; clientsProc.running = true; root.reloadForge(); root.reloadSfx(); root.reloadWebcam(); }
}
