import QtQuick
import Quickshell
import Quickshell.Io

// Restyled hardware monitor: pie + trend per CPU/MEM/NET + expandable process list.
// Toggle with: omarchy-shell shell toggle gennaro.hwmon
Item {
    id: root

    property bool opened: false
    function open(payloadJson: string): void { root.opened = true }
    function close(): void { root.opened = false }

    FloatingWindow {
        id: win

        visible: root.opened
        color: "transparent"
        // Collapsed: header 40 + sep + 3 rows (~72 each) + sep + button 32 + footer 14 + margins
        // Expanded: + process list (~190)
        implicitWidth: 420
        implicitHeight: win.showProcesses ? 640 : 460
        title: "HW Monitor"

        // ---------- Palette ----------
        readonly property color paper:   "#181616"
        readonly property color ink:     "#c5c9c5"
        readonly property color inkDeep: "#c8c093"
        readonly property color inkDim:  Qt.rgba(ink.r, ink.g, ink.b, 0.55)
        readonly property color indigo:  "#658594"
        readonly property color seal:    "#c4746e"
        readonly property color sep:     Qt.rgba(ink.r, ink.g, ink.b, 0.14)
        readonly property color cardBg:  Qt.rgba(ink.r, ink.g, ink.b, 0.04)
        readonly property string mono:   "JetBrainsMono Nerd Font"

        // ---------- State ----------
        property int history: 90
        property int netScale: 1024
        property var cpuValues: []
        property var memValues: []
        property var downValues: []
        property var upValues: []
        property int cpuNow: 0
        property int memNow: 0
        property real downKBps: 0
        property real upKBps: 0
        property real netPercent: 0
        property int _prevRx: -1
        property int _prevTx: -1
        property bool showProcesses: false
        property var topProcesses: []  // [{pid,name,cpu,mem}]

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
                const peak = Math.max(down, up);
                win.netPercent = Math.min(100, (peak / win.netScale) * 100);
            }
            win._prevRx = rx;
            win._prevTx = tx;
        }

        // 1 Hz system probe
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
                        win.push(parseInt(p[0]) || 0, parseInt(p[1]) || 0,
                                 parseInt(p[2]) || 0, parseInt(p[3]) || 0);
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
                if (win.visible) { probe.running = false; probe.running = true; }
            }
        }

        // Process list probe — only when panel is visible and expanded
        Process {
            id: procProbe
            running: false
            command: ["bash", "-lc",
                "ps -eo pid,comm,%cpu,%mem --sort=-%cpu | awk 'NR>1 {printf \"%d|%s|%.1f|%.1f\\n\", $1, $2, $3, $4}' | head -n 8"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = this.text.trim().split("\n");
                    const out = [];
                    for (let i = 0; i < lines.length; i++) {
                        const l = lines[i].trim();
                        if (!l) continue;
                        const parts = l.split("|");
                        if (parts.length !== 4) continue;
                        out.push({ pid: parts[0], name: parts[1], cpu: parts[2], mem: parts[3] });
                    }
                    win.topProcesses = out;
                }
            }
        }
        Timer {
            interval: 2000
            running: win.visible && win.showProcesses
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (win.visible && win.showProcesses) { procProbe.running = false; procProbe.running = true; }
            }
        }

        Rectangle {
            id: card
            anchors.fill: parent
            anchors.margins: 2
            radius: 12
            color: win.paper
            border.color: win.sep
            border.width: 1

            Column {
                id: col
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // Header
                Item {
                    width: parent.width
                    height: 38
                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text {
                            text: "HW MONITOR"
                            color: win.ink
                            font.family: win.mono
                            font.pixelSize: 14
                            font.letterSpacing: 3
                            font.weight: Font.Medium
                        }
                        Text {
                            text: "PIE + TREND  ·  90S WINDOW"
                            color: win.inkDeep
                            font.family: win.mono
                            font.pixelSize: 8
                            font.letterSpacing: 1.8
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: win.visible ? win.seal : win.inkDim
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "LIVE"
                            color: win.inkDim
                            font.family: win.mono
                            font.pixelSize: 9
                            font.letterSpacing: 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: win.sep }

                // --- Metric row component inline ---
                // CPU row
                Item {
                    width: parent.width
                    height: 72
                    Row {
                        anchors.fill: parent
                        spacing: 12
                        PieChart {
                            id: cpuPie
                            anchors.verticalCenter: parent.verticalCenter
                            value: win.cpuNow
                            color: win.seal
                            label: win.cpuNow + "%"
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 58
                            spacing: 2
                            Text {
                                text: "CPU"
                                color: win.inkDeep
                                font.family: win.mono
                                font.pixelSize: 10
                                font.letterSpacing: 2
                            }
                            Text {
                                text: win.cpuNow + "%"
                                color: win.seal
                                font.family: win.mono
                                font.pixelSize: 16
                                font.weight: Font.Medium
                            }
                            Text {
                                text: "used"
                                color: win.inkDim
                                font.family: win.mono
                                font.pixelSize: 8
                            }
                        }
                        Item {
                            width: parent.width - 56 - 58 - 24
                            height: 56
                            anchors.verticalCenter: parent.verticalCenter
                            Sparkline {
                                anchors.fill: parent
                                series: [win.cpuValues]
                                colors: [win.seal]
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                text: win.cpuValues.length + "s"
                                color: win.inkDim
                                font.family: win.mono
                                font.pixelSize: 7
                            }
                        }
                    }
                }

                // MEM row
                Item {
                    width: parent.width
                    height: 72
                    Row {
                        anchors.fill: parent
                        spacing: 12
                        PieChart {
                            value: win.memNow
                            color: win.indigo
                            label: win.memNow + "%"
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 58
                            spacing: 2
                            Text {
                                text: "MEM"
                                color: win.inkDeep
                                font.family: win.mono
                                font.pixelSize: 10
                                font.letterSpacing: 2
                            }
                            Text {
                                text: win.memNow + "%"
                                color: win.indigo
                                font.family: win.mono
                                font.pixelSize: 16
                                font.weight: Font.Medium
                            }
                            Text {
                                text: "used"
                                color: win.inkDim
                                font.family: win.mono
                                font.pixelSize: 8
                            }
                        }
                        Item {
                            width: parent.width - 56 - 58 - 24
                            height: 56
                            anchors.verticalCenter: parent.verticalCenter
                            Sparkline {
                                anchors.fill: parent
                                series: [win.memValues]
                                colors: [win.indigo]
                            }
                        }
                    }
                }

                // NET row
                Item {
                    width: parent.width
                    height: 72
                    Row {
                        anchors.fill: parent
                        spacing: 12
                        PieChart {
                            value: win.netPercent
                            color: win.inkDeep
                            label: Math.round(win.netPercent) + "%"
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 58
                            spacing: 2
                            Text {
                                text: "NET"
                                color: win.inkDeep
                                font.family: win.mono
                                font.pixelSize: 10
                                font.letterSpacing: 2
                            }
                            Text {
                                text: "↓" + Math.round(win.downKBps)
                                color: win.seal
                                font.family: win.mono
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                            Text {
                                text: "↑" + Math.round(win.upKBps) + " KB/s"
                                color: win.inkDim
                                font.family: win.mono
                                font.pixelSize: 8
                            }
                        }
                        Item {
                            width: parent.width - 56 - 58 - 24
                            height: 56
                            anchors.verticalCenter: parent.verticalCenter
                            Sparkline {
                                anchors.fill: parent
                                series: [win.downValues, win.upValues]
                                colors: [win.seal, win.inkDeep]
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                spacing: 6
                                Rectangle { width: 8; height: 3; radius: 1.5; color: win.seal; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "↓"; color: win.inkDim; font.family: win.mono; font.pixelSize: 7 }
                                Rectangle { width: 8; height: 3; radius: 1.5; color: win.inkDeep; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "↑"; color: win.inkDim; font.family: win.mono; font.pixelSize: 7 }
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: win.sep }

                // Toggle button
                Rectangle {
                    id: procBtn
                    width: parent.width
                    height: 32
                    radius: 8
                    color: procMouse.containsMouse ? Qt.rgba(win.ink.r, win.ink.g, win.ink.b, 0.08)
                           : win.cardBg
                    border.color: win.sep
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: win.showProcesses ? "▴  NASCONDI PROCESSI" : "▾  PROCESSI ATTIVI"
                            color: win.ink
                            font.family: win.mono
                            font.pixelSize: 10
                            font.letterSpacing: 1.5
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            visible: win.topProcesses.length > 0
                            text: "(" + win.topProcesses.length + ")"
                            color: win.inkDim
                            font.family: win.mono
                            font.pixelSize: 9
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: procMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.showProcesses = !win.showProcesses
                    }
                }

                // Process list
                Item {
                    width: parent.width
                    height: win.showProcesses ? 168 : 0
                    visible: height > 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Column {
                        anchors.fill: parent
                        spacing: 0

                        // Header row
                        Item {
                            width: parent.width
                            height: 18
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "PID      NOME              CPU%   MEM%"
                                color: win.inkDim
                                font.family: win.mono
                                font.pixelSize: 8
                                font.letterSpacing: 0.8
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: win.sep }

                        Repeater {
                            model: win.topProcesses
                            delegate: Item {
                                width: parent.width
                                height: 18
                                required property var modelData
                                required property int index
                                Rectangle {
                                    anchors.fill: parent
                                    color: index % 2 === 0 ? "transparent" : Qt.rgba(win.ink.r, win.ink.g, win.ink.b, 0.03)
                                }
                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 2
                                    spacing: 0
                                    Text {
                                        width: 52
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.pid
                                        color: win.inkDim
                                        font.family: win.mono
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: 130
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name
                                        color: win.ink
                                        font.family: win.mono
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: 52
                                        anchors.verticalCenter: parent.verticalCenter
                                        horizontalAlignment: Text.AlignRight
                                        text: modelData.cpu + "%"
                                        color: parseFloat(modelData.cpu) > 10 ? win.seal : win.ink
                                        font.family: win.mono
                                        font.pixelSize: 9
                                    }
                                    Text {
                                        width: 52
                                        anchors.verticalCenter: parent.verticalCenter
                                        horizontalAlignment: Text.AlignRight
                                        text: modelData.mem + "%"
                                        color: win.indigo
                                        font.family: win.mono
                                        font.pixelSize: 9
                                    }
                                    // mini bar CPU
                                    Item {
                                        width: 40
                                        height: parent.height
                                        anchors.verticalCenter: parent.verticalCenter
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.min(40, parseFloat(modelData.cpu) * 0.8)
                                            height: 3
                                            radius: 1.5
                                            color: win.seal
                                            opacity: 0.8
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            visible: win.topProcesses.length === 0 && win.showProcesses
                            text: win.visible ? "caricamento processi…" : ""
                            color: win.inkDim
                            font.family: win.mono
                            font.pixelSize: 9
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // Footer
                Item {
                    width: parent.width
                    height: 12
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "NET SCALE " + win.netScale + " KB/s  ·  TAP PROCESSI PER DETTAGLI"
                        color: win.inkDim
                        font.family: win.mono
                        font.pixelSize: 7
                        font.letterSpacing: 0.8
                        opacity: 0.7
                    }
                }
            }
        }
    }
}
