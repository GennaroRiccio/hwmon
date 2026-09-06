import QtQuick
import Quickshell
import Quickshell.Io

// Omarchy plugin variant of the standalone hardware monitor: live CPU, memory
// and network sparklines over a rolling ~90 s window, running inside the
// omarchy-shell process instead of a separate Quickshell instance.
//
// Toggle with:  omarchy-shell shell toggle gennaro.hwmon
// (or a Hyprland keybind dispatching that command). The window is only
// instantiated while summoned — hiding it destroys the probe, so no timers
// keep running in the background.
//
// Uses the same self-contained palette as the standalone version; no
// dependency on qs.Commons/qs.Ui singletons.
Item {
    id: root

    property bool opened: false

    function open(payloadJson: string): void { root.opened = true }
    function close(): void { root.opened = false }

    FloatingWindow {
        id: win

        visible: root.opened
        color: "transparent"
        // Header 40 + sep 1 + 3 rows × 78 + sep 1 + legend 14 + 6 gaps × 12
        // + margins 32 = 394 tall; 400 wide. Keep in sync with the Hyprland
        // `size 400 394` windowrule for title "HW Monitor".
        implicitWidth: 400
        implicitHeight: 394
        title: "HW Monitor"

        // ---------- Palette ----------
        readonly property color paper:   "#181616"
        readonly property color ink:     "#c5c9c5"
        readonly property color inkDeep: "#c8c093"
        readonly property color indigo:  "#658594"
        readonly property color seal:    "#c4746e"
        readonly property color sep:     Qt.rgba(ink.r, ink.g, ink.b, 0.18)
        readonly property string mono:   "JetBrainsMono Nerd Font"

        // ---------- Rolling history ----------
        property int history: 90
        // NET graph saturation in KB/s; anything above pins to the top.
        property int netScale: 1024
        property var cpuValues: []
        property var memValues: []
        property var downValues: []
        property var upValues: []
        property int cpuNow: 0
        property int memNow: 0
        property real downKBps: 0
        property real upKBps: 0
        // Last cumulative rx/tx bytes, seeded on the first sample.
        property int _prevRx: -1
        property int _prevTx: -1

        function push(cpu, mem, rx, tx) {
            win.cpuNow = cpu;
            win.memNow = mem;
            win.cpuValues = [...win.cpuValues, cpu / 100].slice(-win.history);
            win.memValues = [...win.memValues, mem / 100].slice(-win.history);
            if (win._prevRx >= 0) {
                const down = Math.max(0, (rx - win._prevRx) / 1024);
                const up = Math.max(0, (tx - win._prevTx) / 1024);
                win.downKBps = down;
                win.upKBps = up;
                win.downValues = [...win.downValues, Math.min(1, down / win.netScale)].slice(-win.history);
                win.upValues = [...win.upValues, Math.min(1, up / win.netScale)].slice(-win.history);
            }
            win._prevRx = rx;
            win._prevTx = tx;
        }

        // 1 Hz probe. CPU is a delta between two /proc/stat snapshots 0.15 s
        // apart; mem comes from /proc/meminfo; net from cumulative
        // /proc/net/dev counters, skipping loopback so localhost chatter
        // doesn't show as "traffic".
        Process {
            id: probe
            running: false
            command: ["bash", "-lc",
                "read _ a b c d _ < <(grep '^cpu ' /proc/stat); "
                + "sleep 0.15; "
                + "read _ e f g h _ < <(grep '^cpu ' /proc/stat); "
                + "du=$(( (e+f+g) - (a+b+c) )); dt=$(( (e+f+g+h) - (a+b+c+d) )); "
                + "cpu=$(( dt>0 ? du*100/dt : 0 )); "
                + "mem=$(awk '/MemTotal/{t=$2}/MemAvailable/{m=$2}END{printf \"%d\",(t-m)*100/t}' /proc/meminfo); "
                + "read rx tx < <(awk 'NR>2 && $1!~/^lo:/ {r+=$2; t+=$10} END {print r+0, t+0}' /proc/net/dev); "
                + "printf '%d|%d|%d|%d\\n' \"$cpu\" \"$mem\" \"$rx\" \"$tx\""]
            stdout: StdioCollector {
                onStreamFinished: {
                    const p = this.text.trim().split("|");
                    if (p.length === 4) {
                        win.push(parseInt(p[0]) || 0,
                                 parseInt(p[1]) || 0,
                                 parseInt(p[2]) || 0,
                                 parseInt(p[3]) || 0);
                    }
                }
            }
        }
        Timer {
            interval: 1000
            running: win.visible
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (win.visible) {
                    probe.running = false;
                    probe.running = true;
                }
            }
        }

        Rectangle {
            id: card
            anchors.fill: parent
            anchors.margins: 2
            radius: 10
            color: win.paper
            border.color: win.sep
            border.width: 1

            Column {
                id: col
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Item {
                    width: parent.width
                    height: 40

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: "HW MONITOR"
                            color: win.ink
                            font.family: win.mono
                            font.pixelSize: 15
                            font.letterSpacing: 3
                            font.weight: Font.Medium
                        }
                        Text {
                            text: "90S WINDOW"
                            color: win.inkDeep
                            font.family: win.mono
                            font.pixelSize: 9
                            font.letterSpacing: 2
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CPU " + win.cpuNow + "%  ·  MEM " + win.memNow + "%"
                        color: win.ink
                        font.family: win.mono
                        font.pixelSize: 11
                        font.letterSpacing: 1
                    }
                }

                Rectangle { width: parent.width; height: 1; color: win.sep }

                GraphRow {
                    width: parent.width
                    fontFamily: win.mono
                    label: "CPU"
                    valueText: win.cpuNow + "%"
                    valueColor: win.seal
                    series: [win.cpuValues]
                    colors: [win.seal]
                }
                GraphRow {
                    width: parent.width
                    fontFamily: win.mono
                    label: "MEM"
                    valueText: win.memNow + "%"
                    valueColor: win.indigo
                    series: [win.memValues]
                    colors: [win.indigo]
                }
                GraphRow {
                    width: parent.width
                    fontFamily: win.mono
                    label: "NET"
                    valueText: "↓" + Math.round(win.downKBps)
                              + "  ↑" + Math.round(win.upKBps) + " KB/s"
                    valueColor: win.seal
                    series: [win.downValues, win.upValues]
                    colors: [win.seal, win.inkDeep]
                }

                Rectangle { width: parent.width; height: 1; color: win.sep }

                Item {
                    width: parent.width
                    height: 14

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "NET SCALE " + win.netScale + " KB/s"
                        color: win.inkDeep
                        font.family: win.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        opacity: 0.7
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Rectangle { width: 8; height: 3; radius: 1.5; color: win.seal; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: "↓"
                            color: win.inkDeep
                            font.family: win.mono
                            font.pixelSize: 9
                        }
                        Rectangle { width: 8; height: 3; radius: 1.5; color: win.inkDeep; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: "↑"
                            color: win.inkDeep
                            font.family: win.mono
                            font.pixelSize: 9
                        }
                    }
                }
            }
        }
    }
}
