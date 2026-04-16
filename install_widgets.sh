#!/usr/bin/env bash
# ============================================================
# install_widgets.sh — End4 Quickshell Custom Widget Installer
# Adds: Audio Visualizer, Stats (GitHub/Codeforces), System Resources
# ============================================================

set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────
QS_DIR="${1:-$HOME/.config/quickshell/ii}"
BACKUP_DIR="$QS_DIR/widget_install_backup_$(date +%Y%m%d_%H%M%S)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()    { echo -e "${RED}[ERR]${NC} $*"; exit 1; }

# ── PREFLIGHT ─────────────────────────────────────────────────
[[ -d "$QS_DIR" ]]                         || fail "Quickshell dir not found: $QS_DIR\nUsage: $0 [path-to-quickshell-ii-dir]"
[[ -f "$QS_DIR/modules/common/Config.qml" ]] || fail "Config.qml not found — is this an end4 config?"
command -v python3 &>/dev/null             || fail "python3 is required"
command -v cava &>/dev/null                || warn "cava not installed — the Visualizer widget will not work"

info "Target: $QS_DIR"
info "Backing up modified files to $BACKUP_DIR …"
mkdir -p "$BACKUP_DIR"
for f in \
    modules/common/Config.qml \
    modules/settings/BackgroundConfig.qml \
    modules/ii/background/Background.qml; do
    cp "$QS_DIR/$f" "$BACKUP_DIR/$(basename $f).bak"
done
success "Backup done"

# ── HELPER: python patch ───────────────────────────────────────
# Usage: patch_file FILE ANCHOR INSERT_AFTER(true/false) TEXT
patch_after()  { python3 -c "
import sys
file, anchor, text = sys.argv[1], sys.argv[2], sys.argv[3]
content = open(file).read()
if text.strip() in content:
    print('  already patched, skipping')
    sys.exit(0)
if anchor not in content:
    print(f'  anchor not found in {file}', file=sys.stderr); sys.exit(1)
new = content.replace(anchor, anchor + text, 1)
open(file, 'w').write(new)
" "$@"; }

patch_before() { python3 -c "
import sys
file, anchor, text = sys.argv[1], sys.argv[2], sys.argv[3]
content = open(file).read()
if text.strip() in content:
    print('  already patched, skipping')
    sys.exit(0)
if anchor not in content:
    print(f'  anchor not found in {file}', file=sys.stderr); sys.exit(1)
new = content.replace(anchor, text + anchor, 1)
open(file, 'w').write(new)
" "$@"; }

# ════════════════════════════════════════════════════════════════
# 1. PATCH Config.qml — add widget schemas
# ════════════════════════════════════════════════════════════════
info "Patching Config.qml …"
CONFIG="$QS_DIR/modules/common/Config.qml"

WEATHER_ANCHOR='property JsonObject weather: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free" // "free", "leastBusy", "mostBusy"
                        property real x: 400
                        property real y: 100
                    }'

WIDGET_ADDITIONS='
                    property JsonObject visualizer: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 500
                        property real y: 500
                        property int bars: 30
                        property string style: "bars"
                        property bool vertical: false
                    }
                    property JsonObject stats: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 150
                        property real y: 300
                        property string githubUsername: ""
                        property string codeforcesUsername: ""
                        property bool showGraphs: false
                    }
                    property JsonObject systemResources: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 150
                        property real y: 600
                        property bool showGraphs: false
                    }'

patch_after "$CONFIG" "$WEATHER_ANCHOR" "$WIDGET_ADDITIONS"
success "Config.qml patched"

# ════════════════════════════════════════════════════════════════
# 2. PATCH BackgroundConfig.qml — add settings UI sections
# ════════════════════════════════════════════════════════════════
info "Patching BackgroundConfig.qml …"
BGCFG="$QS_DIR/modules/settings/BackgroundConfig.qml"

# Find the closing of the Weather section (last closing brace before end of file)
# We inject the new sections before the final closing brace
BGCFG_ANCHOR='}'  # last } in file — use python directly

python3 - "$BGCFG" <<'PYEOF'
import sys, re

file = sys.argv[1]
content = open(file).read()

new_sections = r"""
    ContentSection {
        icon: "equalizer"
        title: Translation.tr("Widget: Audio Visualizer")

        ConfigRow {
            Layout.fillWidth: true
            ConfigSwitch {
                Layout.fillWidth: false
                buttonIcon: "check"
                text: Translation.tr("Enable")
                checked: Config.options.background.widgets.visualizer.enable
                onCheckedChanged: { Config.options.background.widgets.visualizer.enable = checked; }
            }
            Item { Layout.fillWidth: true }
            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: Config.options.background.widgets.visualizer.placementStrategy
                onSelected: newValue => { Config.options.background.widgets.visualizer.placementStrategy = newValue; }
                options: [
                    { displayName: Translation.tr("Draggable"), icon: "drag_pan", value: "free" },
                    { displayName: Translation.tr("Least busy"), icon: "category", value: "leastBusy" },
                    { displayName: Translation.tr("Most busy"), icon: "shapes", value: "mostBusy" },
                ]
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "vertical_distribute"
                text: Translation.tr("Vertical")
                checked: Config.options.background.widgets.visualizer.vertical
                onCheckedChanged: { Config.options.background.widgets.visualizer.vertical = checked; }
            }
        }
        ConfigSelectionArray {
            currentValue: Config.options.background.widgets.visualizer.style
            onSelected: newValue => { Config.options.background.widgets.visualizer.style = newValue; }
            options: [
                { displayName: Translation.tr("Bars"), icon: "bar_chart", value: "bars" },
                { displayName: Translation.tr("Wave"), icon: "water", value: "wave" }
            ]
        }
        ConfigSpinBox {
            icon: "add_chart"
            text: Translation.tr("Bars")
            value: Config.options.background.widgets.visualizer.bars
            from: 10; to: 100; stepSize: 1
            onValueChanged: { Config.options.background.widgets.visualizer.bars = value; }
        }
    }

    ContentSection {
        icon: "query_stats"
        title: Translation.tr("Widget: Stats (GitHub & Codeforces)")

        ConfigRow {
            Layout.fillWidth: true
            ConfigSwitch {
                Layout.fillWidth: false
                buttonIcon: "check"
                text: Translation.tr("Enable")
                checked: Config.options.background.widgets.stats.enable
                onCheckedChanged: { Config.options.background.widgets.stats.enable = checked; }
            }
            Item { Layout.fillWidth: true }
            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: Config.options.background.widgets.stats.placementStrategy
                onSelected: newValue => { Config.options.background.widgets.stats.placementStrategy = newValue; }
                options: [
                    { displayName: Translation.tr("Draggable"), icon: "drag_pan", value: "free" },
                    { displayName: Translation.tr("Least busy"), icon: "category", value: "leastBusy" },
                    { displayName: Translation.tr("Most busy"), icon: "shapes", value: "mostBusy" },
                ]
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "show_chart"
                text: Translation.tr("Show Graphs")
                checked: Config.options.background.widgets.stats.showGraphs
                onCheckedChanged: { Config.options.background.widgets.stats.showGraphs = checked; }
            }
        }
        ContentSubsection {
            title: Translation.tr("Usernames")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("GitHub Username")
                text: Config.options.background.widgets.stats.githubUsername
                wrapMode: TextEdit.Wrap
                onTextChanged: { Config.options.background.widgets.stats.githubUsername = text; }
            }
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Codeforces Username")
                text: Config.options.background.widgets.stats.codeforcesUsername
                wrapMode: TextEdit.Wrap
                onTextChanged: { Config.options.background.widgets.stats.codeforcesUsername = text; }
            }
        }
    }

    ContentSection {
        icon: "memory"
        title: Translation.tr("Widget: System Resources")

        ConfigRow {
            Layout.fillWidth: true
            ConfigSwitch {
                Layout.fillWidth: false
                buttonIcon: "check"
                text: Translation.tr("Enable")
                checked: Config.options.background.widgets.systemResources.enable
                onCheckedChanged: { Config.options.background.widgets.systemResources.enable = checked; }
            }
            Item { Layout.fillWidth: true }
            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: Config.options.background.widgets.systemResources.placementStrategy
                onSelected: newValue => { Config.options.background.widgets.systemResources.placementStrategy = newValue; }
                options: [
                    { displayName: Translation.tr("Draggable"), icon: "drag_pan", value: "free" },
                    { displayName: Translation.tr("Least busy"), icon: "category", value: "leastBusy" },
                    { displayName: Translation.tr("Most busy"), icon: "shapes", value: "mostBusy" },
                ]
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "show_chart"
                text: Translation.tr("Show Smooth Graphs")
                checked: Config.options.background.widgets.systemResources.showGraphs
                onCheckedChanged: { Config.options.background.widgets.systemResources.showGraphs = checked; }
            }
        }
    }
"""

marker = "// __CUSTOM_WIDGETS_INSERTED__"
if marker in content:
    print("  already patched, skipping")
    sys.exit(0)

# Insert before the very last } in the file
last_brace = content.rfind('\n}')
if last_brace == -1:
    print("Could not find closing brace", file=sys.stderr); sys.exit(1)

content = content[:last_brace] + '\n' + marker + new_sections + content[last_brace:]
open(file, 'w').write(content)
PYEOF
success "BackgroundConfig.qml patched"

# ════════════════════════════════════════════════════════════════
# 3. PATCH Background.qml — add imports + FadeLoader instances
# ════════════════════════════════════════════════════════════════
info "Patching Background.qml …"
BG="$QS_DIR/modules/ii/background/Background.qml"

patch_after "$BG" \
    "import qs.modules.ii.background.widgets.weather" \
    $'\nimport qs.modules.ii.background.widgets.visualizer\nimport qs.modules.ii.background.widgets.stats\nimport qs.modules.ii.background.widgets.resources'

python3 - "$BG" <<'PYEOF'
import sys
file = sys.argv[1]
content = open(file).read()
marker = "// __CUSTOM_FADERS_INSERTED__"
if marker in content:
    print("  already patched, skipping"); sys.exit(0)

new_faders = """
                """ + marker + """
                FadeLoader {
                    shown: Config.options.background.widgets.visualizer.enable
                    sourceComponent: VisualizerWidget {
                        screenWidth: bgRoot.screen.width; screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width; scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }
                FadeLoader {
                    shown: Config.options.background.widgets.stats.enable
                    sourceComponent: StatsWidget {
                        screenWidth: bgRoot.screen.width; screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width; scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }
                FadeLoader {
                    shown: Config.options.background.widgets.systemResources.enable
                    sourceComponent: SystemResourcesWidget {
                        screenWidth: bgRoot.screen.width; screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width; scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }"""

# Find the last FadeLoader block (ClockWidget) and append after its closing }
import re
# Insert before triple-closing `            }\n        }\n    }\n}`
anchor = re.search(r'(\s+}\n\s+}\n\s+}\n})\s*$', content)
if not anchor:
    print("Could not find insertion anchor in Background.qml", file=sys.stderr); sys.exit(1)
pos = anchor.start(1)
content = content[:pos] + new_faders + content[pos:]
open(file, 'w').write(content)
PYEOF
success "Background.qml patched"

# ════════════════════════════════════════════════════════════════
# 4. CREATE widget files
# ════════════════════════════════════════════════════════════════
info "Creating widget directories …"
mkdir -p "$QS_DIR/modules/ii/background/widgets/visualizer"
mkdir -p "$QS_DIR/modules/ii/background/widgets/stats"
mkdir -p "$QS_DIR/modules/ii/background/widgets/resources"

# ── VisualizerWidget.qml ───────────────────────────────────────
info "Writing VisualizerWidget.qml …"
cat > "$QS_DIR/modules/ii/background/widgets/visualizer/VisualizerWidget.qml" <<'QMLEOF'
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "visualizer"
    implicitHeight: backgroundShape.implicitHeight
    implicitWidth: backgroundShape.implicitWidth

    property int numBars: Config.options.background.widgets.visualizer.bars
    property bool isVertical: Config.options.background.widgets.visualizer.vertical
    property string style: Config.options.background.widgets.visualizer.style
    property var amplitudeArray: []

    Component.onCompleted: {
        for(let i = 0; i < numBars; i++) amplitudeArray.push(0);
    }

    onNumBarsChanged: {
        var arr = [];
        for(let i = 0; i < numBars; i++) arr.push(0);
        amplitudeArray = arr;
        cavaProcess.running = false;
        cavaProcess.running = true;
    }

    Process {
        id: createCavaConfig
        command: ["bash", "-c",
            "echo -e '[general]\nbars = " + root.numBars +
            "\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\n' > /tmp/quickshell_cava_config"]
        running: true
        onExited: cavaProcess.running = true
    }

    Process {
        id: cavaProcess
        running: false
        command: ["cava", "-p", "/tmp/quickshell_cava_config"]
        stdout: SplitParser {
            onRead: (line) => {
                var vals = line.split(';').map(s => parseInt(s, 10)).filter(v => !isNaN(v));
                if (vals.length > 0) root.amplitudeArray = vals;
            }
        }
    }

    Rectangle {
        id: backgroundShape
        anchors.fill: parent
        color: "transparent"
        implicitWidth:  isVertical ? 200 : (numBars * 10 + 40)
        implicitHeight: isVertical ? (numBars * 10 + 40) : 200

        Item {
            anchors.fill: parent
            anchors.margins: 20

            // Horizontal base line
            Rectangle {
                visible: !isVertical
                color: Appearance.colors.colPrimary
                height: 4; width: parent.width
                anchors.bottom: parent.bottom
                radius: 2
            }
            // Vertical base line
            Rectangle {
                visible: isVertical
                color: Appearance.colors.colPrimary
                width: 4; height: parent.height
                anchors.left: parent.left
                radius: 2
            }

            // Horizontal bars
            Row {
                anchors.fill: parent; spacing: 4
                visible: !isVertical && style === "bars"
                Repeater {
                    model: root.amplitudeArray
                    Rectangle {
                        width: parent.width / root.amplitudeArray.length - parent.spacing
                        height: Math.max(2, (modelData / 100) * parent.height)
                        anchors.bottom: parent.bottom
                        color: Appearance.colors.colPrimary; radius: 2
                        Behavior on height { NumberAnimation { duration: 50; easing.type: Easing.OutSine } }
                    }
                }
            }

            // Vertical bars
            Column {
                anchors.fill: parent; spacing: 4
                visible: isVertical && style === "bars"
                Repeater {
                    model: root.amplitudeArray
                    Rectangle {
                        height: parent.height / root.amplitudeArray.length - parent.spacing
                        width: Math.max(2, (modelData / 100) * parent.width)
                        anchors.left: parent.left
                        color: Appearance.colors.colPrimary; radius: 2
                        Behavior on width { NumberAnimation { duration: 50; easing.type: Easing.OutSine } }
                    }
                }
            }

            // Wave (smooth bezier)
            Canvas {
                anchors.fill: parent
                visible: style === "wave"
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.beginPath();
                    ctx.strokeStyle = Appearance.colors.colPrimary;
                    ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.lineJoin = "round";
                    var arr = root.amplitudeArray;
                    if (arr.length < 2) return;
                    if (!isVertical) {
                        var stepX = width / (arr.length - 1);
                        ctx.moveTo(0, height - (arr[0]/100)*height);
                        for(var i=1; i<arr.length; i++) {
                            var cpx = ((i-1)*stepX + i*stepX) / 2;
                            ctx.bezierCurveTo(cpx, height-(arr[i-1]/100)*height, cpx, height-(arr[i]/100)*height, i*stepX, height-(arr[i]/100)*height);
                        }
                    } else {
                        var stepY = height / (arr.length - 1);
                        ctx.moveTo((arr[0]/100)*width, 0);
                        for(var j=1; j<arr.length; j++) {
                            var cpy = ((j-1)*stepY + j*stepY) / 2;
                            ctx.bezierCurveTo((arr[j-1]/100)*width, cpy, (arr[j]/100)*width, cpy, (arr[j]/100)*width, j*stepY);
                        }
                    }
                    ctx.stroke();
                }
                Timer { interval: 16; running: root.style === "wave"; repeat: true; onTriggered: parent.requestPaint() }
            }
        }
    }
}
QMLEOF
success "VisualizerWidget.qml written"

# ── StatsWidget.qml ────────────────────────────────────────────
info "Writing StatsWidget.qml …"
cat > "$QS_DIR/modules/ii/background/widgets/stats/StatsWidget.qml" <<'QMLEOF'
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "stats"
    implicitHeight: backgroundShape.implicitHeight
    implicitWidth: backgroundShape.implicitWidth

    property string githubUsername: Config.options.background.widgets.stats.githubUsername
    property string codeforcesUsername: Config.options.background.widgets.stats.codeforcesUsername
    property bool showGraphs: Config.options.background.widgets.stats.showGraphs || false

    property int ghFollowers: 0
    property int ghRepos: 0
    property string cfRank: "--"
    property int cfRating: 0
    property var githubActivityArray: []
    property var cfActivityArray: []
    property int maxGithubActivity: 1
    property int maxCfActivity: 1

    function fetchGithub() {
        if (!githubUsername) return;
        var req = new XMLHttpRequest();
        req.onreadystatechange = function() {
            if (req.readyState === 4 && req.status === 200) {
                var data = JSON.parse(req.responseText);
                ghFollowers = data.followers || 0;
                ghRepos = data.public_repos || 0;
            }
        }
        req.open("GET", "https://api.github.com/users/" + githubUsername, true);
        req.send();

        if (showGraphs) {
            var ereq = new XMLHttpRequest();
            ereq.onreadystatechange = function() {
                if (ereq.readyState !== 4 || ereq.status !== 200) return;
                var events = JSON.parse(ereq.responseText);
                var bins = new Array(30).fill(0), maxV = 0, now = new Date();
                for (var i = 0; i < events.length; i++) {
                    var d = Math.floor(Math.abs(now - new Date(events[i].created_at)) / 86400000);
                    if (d < 30) { bins[29-d]++; if (bins[29-d] > maxV) maxV = bins[29-d]; }
                }
                maxGithubActivity = Math.max(1, maxV);
                githubActivityArray = bins;
            }
            ereq.open("GET", "https://api.github.com/users/" + githubUsername + "/events/public?per_page=100", true);
            ereq.send();
        }
    }

    function fetchCodeforces() {
        if (!codeforcesUsername) return;
        var req = new XMLHttpRequest();
        req.onreadystatechange = function() {
            if (req.readyState === 4 && req.status === 200) {
                var data = JSON.parse(req.responseText);
                if (data.status === "OK" && data.result.length > 0) {
                    cfRank = data.result[0].rank || "--";
                    cfRating = data.result[0].rating || 0;
                }
            }
        }
        req.open("GET", "https://codeforces.com/api/user.info?handles=" + codeforcesUsername, true);
        req.send();

        if (showGraphs) {
            var sreq = new XMLHttpRequest();
            sreq.onreadystatechange = function() {
                if (sreq.readyState !== 4 || sreq.status !== 200) return;
                var data = JSON.parse(sreq.responseText);
                if (data.status !== "OK") return;
                var bins = new Array(30).fill(0), maxV = 0, nowS = Date.now()/1000;
                for (var i = 0; i < data.result.length; i++) {
                    var d = Math.floor((nowS - data.result[i].creationTimeSeconds) / 86400);
                    if (d < 30) { bins[29-d]++; if (bins[29-d] > maxV) maxV = bins[29-d]; }
                }
                maxCfActivity = Math.max(1, maxV);
                cfActivityArray = bins;
            }
            sreq.open("GET", "https://codeforces.com/api/user.status?handle=" + codeforcesUsername + "&from=1&count=200", true);
            sreq.send();
        }
    }

    Timer { interval: 600000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { fetchGithub(); fetchCodeforces(); } }
    onGithubUsernameChanged: fetchGithub()
    onCodeforcesUsernameChanged: fetchCodeforces()
    onShowGraphsChanged: { if (showGraphs) { fetchGithub(); fetchCodeforces(); } }

    StyledDropShadow { target: backgroundShape }

    Rectangle {
        id: backgroundShape
        anchors.fill: parent
        radius: Appearance.rounding.windowRounding
        color: Appearance.colors.colPrimaryContainer
        implicitWidth: 320
        implicitHeight: contentCol.implicitHeight + 40

        Column {
            id: contentCol
            anchors.centerIn: parent
            spacing: 20
            width: parent.width - 40

            // GitHub
            Row {
                spacing: 15
                MaterialSymbol { iconSize: 40; color: Appearance.colors.colOnPrimaryContainer; text: "code"; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    StyledText { font.pixelSize: 18; font.weight: Font.Bold; color: Appearance.colors.colOnPrimaryContainer; text: "GitHub: " + (githubUsername || "Not set") }
                    StyledText { font.pixelSize: 14; color: Appearance.colors.colPrimary; text: ghFollowers + " Followers  •  " + ghRepos + " Repos" }
                }
            }
            Canvas {
                width: parent.width; height: root.showGraphs ? 40 : 0; visible: root.showGraphs
                onPaint: {
                    var ctx = getContext("2d"); ctx.clearRect(0,0,width,height);
                    var arr = root.githubActivityArray;
                    if (!arr || arr.length < 2) return;
                    ctx.beginPath(); ctx.strokeStyle = Appearance.colors.colSecondary;
                    ctx.lineWidth = 2; ctx.lineCap = "round"; ctx.lineJoin = "round";
                    var step = width/(arr.length-1);
                    ctx.moveTo(0, height - (arr[0]/root.maxGithubActivity)*(height-4)-2);
                    for(var i=1;i<arr.length;i++){
                        var cpx=((i-1)*step+i*step)/2;
                        var py=height-(arr[i-1]/root.maxGithubActivity)*(height-4)-2;
                        var cy=height-(arr[i]/root.maxGithubActivity)*(height-4)-2;
                        ctx.bezierCurveTo(cpx,py,cpx,cy,i*step,cy);
                    }
                    ctx.stroke();
                }
                Timer { interval: 1000; running: root.showGraphs; repeat: true; onTriggered: parent.requestPaint() }
            }

            // Codeforces
            Row {
                spacing: 15
                MaterialSymbol { iconSize: 40; color: Appearance.colors.colOnPrimaryContainer; text: "bar_chart"; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    StyledText { font.pixelSize: 18; font.weight: Font.Bold; color: Appearance.colors.colOnPrimaryContainer; text: "Codeforces: " + (codeforcesUsername || "Not set") }
                    StyledText { font.pixelSize: 14; color: Appearance.colors.colPrimary; text: "Rating: " + cfRating + "  •  " + cfRank }
                }
            }
            Canvas {
                width: parent.width; height: root.showGraphs ? 40 : 0; visible: root.showGraphs
                onPaint: {
                    var ctx = getContext("2d"); ctx.clearRect(0,0,width,height);
                    var arr = root.cfActivityArray;
                    if (!arr || arr.length < 2) return;
                    ctx.beginPath(); ctx.strokeStyle = Appearance.colors.colError;
                    ctx.lineWidth = 2; ctx.lineCap = "round"; ctx.lineJoin = "round";
                    var step = width/(arr.length-1);
                    ctx.moveTo(0, height - (arr[0]/root.maxCfActivity)*(height-4)-2);
                    for(var i=1;i<arr.length;i++){
                        var cpx=((i-1)*step+i*step)/2;
                        var py=height-(arr[i-1]/root.maxCfActivity)*(height-4)-2;
                        var cy=height-(arr[i]/root.maxCfActivity)*(height-4)-2;
                        ctx.bezierCurveTo(cpx,py,cpx,cy,i*step,cy);
                    }
                    ctx.stroke();
                }
                Timer { interval: 1000; running: root.showGraphs; repeat: true; onTriggered: parent.requestPaint() }
            }
        }
    }
}
QMLEOF
success "StatsWidget.qml written"

# ── SystemResourcesWidget.qml ──────────────────────────────────
info "Writing SystemResourcesWidget.qml …"
cat > "$QS_DIR/modules/ii/background/widgets/resources/SystemResourcesWidget.qml" <<'QMLEOF'
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "systemResources"
    implicitHeight: backgroundShape.implicitHeight
    implicitWidth: backgroundShape.implicitWidth

    property bool showGraphs: Config.options.background.widgets.systemResources.showGraphs || false
    property int maxHistory: ResourceUsage.historyLength
    property var gpuUsageHistory: []
    property real currentGpuUsage: 0

    Component.onCompleted: {
        var arr = [];
        for (var i = 0; i < maxHistory; i++) arr.push(0);
        gpuUsageHistory = arr;
    }

    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: gpuProcess.running = true }

    Process {
        id: gpuProcess
        running: false
        command: ["bash", "-c",
            "if command -v nvidia-smi &>/dev/null; then nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits; " +
            "elif [ -f /sys/class/drm/card0/device/gpu_busy_percent ]; then cat /sys/class/drm/card0/device/gpu_busy_percent; " +
            "else echo 0; fi"]
        stdout: SplitParser {
            onRead: (line) => {
                var v = parseFloat(line.trim());
                if (!isNaN(v)) {
                    root.currentGpuUsage = v;
                    var arr = [...root.gpuUsageHistory, v/100.0];
                    if (arr.length > root.maxHistory) arr.shift();
                    root.gpuUsageHistory = arr;
                }
            }
        }
    }

    StyledDropShadow { target: backgroundShape }

    Rectangle {
        id: backgroundShape
        anchors.fill: parent
        radius: Appearance.rounding.windowRounding
        color: Appearance.colors.colPrimaryContainer
        implicitWidth: 350
        implicitHeight: contentCol.implicitHeight + 40

        Column {
            id: contentCol
            anchors.centerIn: parent
            spacing: 20
            width: parent.width - 40

            Row {
                spacing: 15
                MaterialSymbol { iconSize: 32; color: Appearance.colors.colOnPrimaryContainer; text: "memory"; anchors.verticalCenter: parent.verticalCenter }
                StyledText { font.pixelSize: 18; font.weight: Font.Bold; color: Appearance.colors.colOnPrimaryContainer; text: "System Resources"; anchors.verticalCenter: parent.verticalCenter }
            }

            Row {
                spacing: 30
                anchors.horizontalCenter: parent.horizontalCenter
                Column {
                    StyledText { text: "CPU"; font.pixelSize: 12; color: Appearance.colors.colPrimary }
                    StyledText { text: Math.round(ResourceUsage.cpuUsage * 100) + "%"; font.pixelSize: 18; color: Appearance.colors.colOnPrimaryContainer; font.weight: Font.Bold }
                }
                Column {
                    StyledText { text: "RAM"; font.pixelSize: 12; color: Appearance.colors.colPrimary }
                    StyledText { text: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%"; font.pixelSize: 18; color: Appearance.colors.colOnPrimaryContainer; font.weight: Font.Bold }
                }
                Column {
                    StyledText { text: "GPU"; font.pixelSize: 12; color: Appearance.colors.colPrimary }
                    StyledText { text: Math.round(root.currentGpuUsage) + "%"; font.pixelSize: 18; color: Appearance.colors.colOnPrimaryContainer; font.weight: Font.Bold }
                }
            }

            Canvas {
                id: graphCanvas
                width: parent.width; height: 100; visible: root.showGraphs
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    function drawSmooth(arr, color) {
                        if (!arr || arr.length < 2) return;
                        ctx.beginPath();
                        ctx.strokeStyle = color; ctx.lineWidth = 2;
                        ctx.lineCap = "round"; ctx.lineJoin = "round";
                        var n = arr.length, step = width/(n-1);
                        ctx.moveTo(0, height - arr[0]*(height-4) - 2);
                        for (var i=1; i<n; i++) {
                            var cpx = ((i-1)*step + i*step)/2;
                            var py = height - arr[i-1]*(height-4) - 2;
                            var cy = height - arr[i]*(height-4) - 2;
                            ctx.bezierCurveTo(cpx, py, cpx, cy, i*step, cy);
                        }
                        ctx.stroke();
                    }

                    drawSmooth(root.gpuUsageHistory, Appearance.colors.colError);
                    drawSmooth(ResourceUsage.memoryUsageHistory, Appearance.colors.colSecondary);
                    drawSmooth(ResourceUsage.cpuUsageHistory, Appearance.colors.colPrimary);
                }
                Timer { interval: 1000; running: root.showGraphs; repeat: true; onTriggered: parent.requestPaint() }

                Row {
                    anchors.top: parent.bottom; anchors.topMargin: 5
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 15
                    Repeater {
                        model: [
                            { label: "CPU",  color: Appearance.colors.colPrimary },
                            { label: "RAM",  color: Appearance.colors.colSecondary },
                            { label: "GPU",  color: Appearance.colors.colError }
                        ]
                        Row {
                            spacing: 5
                            required property var modelData
                            Rectangle { width: 10; height: 10; radius: 5; color: modelData.color; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: modelData.label; font.pixelSize: 10; color: Appearance.colors.colOnPrimaryContainer }
                        }
                    }
                }
            }

            Item { width: 1; height: root.showGraphs ? 20 : 0 }
        }
    }
}
QMLEOF
success "SystemResourcesWidget.qml written"

# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN} Installation complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "  Backups saved to: ${CYAN}$BACKUP_DIR${NC}"
echo ""
echo -e "  Enable widgets in: ${CYAN}Settings → Background${NC}"
echo -e "    • Audio Visualizer    (requires ${YELLOW}cava${NC})"
echo -e "    • Stats               (GitHub + Codeforces)"
echo -e "    • System Resources    (CPU / RAM / GPU)"
echo ""
echo -e "  ${YELLOW}Restart Quickshell to apply:${NC}  qs -c \$qsConfig reload"
