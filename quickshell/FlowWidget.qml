import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets
import Quickshell
import Quickshell.Io

AbstractBackgroundWidget {
    id: root

    configEntryName: "flow"

    // Important: size the mouse hitbox to the *visible* box.
    // If we size from `contentColumn` implicit size, it can evaluate to 0,
    // making the widget render but not receive hover/press events.
    implicitHeight: flowBox.implicitHeight
    implicitWidth: flowBox.implicitWidth

    visibleWhenLocked: true
    needsColText: false

    x: targetX
    y: targetY

    width: implicitWidth
    height: implicitHeight

    readonly property string nekoFlowConfigDir: FileUtils.trimFileProtocol(`${Directories.home}/.config/neko-flow`)
    readonly property string nekoFlowLibDir: FileUtils.trimFileProtocol(`${Directories.home}/.local/share/neko-flow/lib`)

    FileView {
        id: flowModesFile
        path: `${root.nekoFlowConfigDir}/flow_modes.txt`
        watchChanges: true

        function parseFlowModes() {
            const raw = flowModesFile.text();
            const out = [];
            for (const line of raw.split(/\r?\n/)) {
                const trimmed = line.trim();
                const m = trimmed.match(/^\[([^\]]+)\]\s*$/);
                if (m) {
                    out.push(m[1].trim().toUpperCase());
                    continue;
                }
            }
            if (out.length === 0) {
                for (const line of raw.split(/\r?\n/)) {
                    const t = line.split("#")[0].trim().toUpperCase();
                    if (t.length > 0 && !t.startsWith("["))
                        out.push(t);
                }
            }
            root.flowModes = out.length > 0 ? out : root.flowModesDefault.slice();
            modeFile.updateMode();
            flowMetaDebounce.restart();
        }

        onLoaded: parseFlowModes()
        onFileChanged: {
            reload();
            flowModesSyncTimer.restart();
        }
    }

    Timer {
        id: flowModesSyncTimer
        interval: 80
        repeat: false
        onTriggered: flowModesFile.parseFlowModes()
    }

    readonly property var flowModesDefault: [
        "COMMS", "BIZDEV", "LEGAL", "HR", "FINANCE", "ADMIN", "CLEAN", "WORK", "CREATE", "EXPLORE"
    ]
    property var flowModes: ["COMMS", "BIZDEV", "LEGAL", "HR", "FINANCE", "ADMIN", "CLEAN", "WORK", "CREATE", "EXPLORE"]

    FileView {
        id: modeFile
        path: `${root.nekoFlowConfigDir}/current_mode`
        watchChanges: true

        function updateMode() {
            const raw = modeFile.text().trim().toUpperCase();
            root.currentMode = root.normalizeMode(raw);
        }

        onLoaded: updateMode()
        onFileChanged: {
            reload();
            modeFileSyncTimer.restart();
        }
    }

    Timer {
        id: modeFileSyncTimer
        interval: 80
        repeat: false
        onTriggered: modeFile.updateMode()
    }

    readonly property list<string> extraModes: ["RECOVER", "STUCK"]

    property string currentMode: "WORK"
    property string currentOption: ""
    property string executedOption: ""
    property string executedTimestamp: ""
    readonly property bool currentModeIsExtra: extraModes.indexOf(currentMode) !== -1

    function normalizeMode(mode) {
        if (flowModes.indexOf(mode) !== -1)
            return mode;
        if (extraModes.indexOf(mode) !== -1)
            return mode;
        return flowModes.indexOf("WORK") !== -1 ? "WORK" : flowModes[0];
    }

    readonly property string nekoFlowParserPath: `${root.nekoFlowLibDir}/neko_flow_doc_parse.py`
    readonly property string nekoSetModeScript: `${root.nekoFlowLibDir}/set_mode.sh`
    readonly property string nekoSetOptionScript: `${root.nekoFlowLibDir}/set_option.sh`
    readonly property string nekoOpenNotesScript: `${root.nekoFlowLibDir}/open_flow_notes.sh`
    readonly property string nekoFlowButtonScript: `${root.nekoFlowLibDir}/execute_flow_button.sh`

    function flowClickButton(buttonId) {
        const id = String(buttonId).trim();
        if (!id.length)
            return;
        Quickshell.execDetached([
            "bash",
            root.nekoFlowButtonScript,
            id,
            root.currentMode,
            root.currentOption
        ]);
    }

    function flowSelectMode(mode) {
        const m = String(mode).toUpperCase();
        if (m === root.currentMode && !root.currentModeIsExtra)
            return;
        Quickshell.execDetached(["bash", root.nekoSetModeScript, m]);
    }

    function flowSelectOption(option) {
        const opt = String(option).trim();
        if (!opt.length || opt === root.currentOption)
            return;
        Quickshell.execDetached(["bash", root.nekoSetOptionScript, opt]);
    }

    function flowOpenNotesInSublime() {
        const mode = root.currentMode;
        if (root.flowNotesWatchPath.length > 0) {
            Quickshell.execDetached([
                "bash",
                root.nekoOpenNotesScript,
                "--path",
                root.flowNotesWatchPath
            ]);
            return;
        }
        if (mode.length === 0)
            return;
        Quickshell.execDetached(["bash", root.nekoOpenNotesScript, mode]);
    }

    // Substates: only from `python3 neko_flow_doc_parse.py meta <MODE>` (overview [SubStates] or DEFAULT_OPTIONS).
    // No duplicate lists here — avoids drift vs cycle_option / execute_flow_option.
    property var flowDocOptions: []
    property string flowOverviewWatchPath: ""
    property string flowRoutineTitle: ""
    property string flowRoutineDescription: ""
    property string flowTasksTitle: ""
    property string flowTasksDescription: ""
    property var flowRoutineOptions: []
    property var flowTasksOptions: []
    property var flowRoutineGlobalIndices: []
    property var flowTasksGlobalIndices: []
    property string flowNotesTitle: ""
    property string flowNotesBody: ""
    property string flowNotesWatchPath: ""
    property string flowModeDescription: ""
    // Map: global option index (string key) -> description
    property var flowOptionDescriptions: ({})
    property var flowOptionButtons: ({})
    // Map: optionIndex -> inline header title
    property var flowInlineHeaders: ({})

    // Incremented each time meta is requested; stale subprocess responses are ignored.
    property int flowMetaSeq: 0
    property int flowMetaAppliedSeq: -1

    function clearFlowDocState() {
        root.flowDocOptions = [];
        root.flowRoutineTitle = "";
        root.flowRoutineDescription = "";
        root.flowTasksTitle = "";
        root.flowTasksDescription = "";
        root.flowRoutineOptions = [];
        root.flowTasksOptions = [];
        root.flowRoutineGlobalIndices = [];
        root.flowTasksGlobalIndices = [];
        root.flowNotesTitle = "";
        root.flowNotesBody = "";
        root.flowModeDescription = "";
        root.flowOptionDescriptions = ({});
        root.flowOptionButtons = ({});
        root.flowInlineHeaders = ({});
    }

    function requestFlowMeta() {
        root.flowMetaSeq += 1;
        flowMetaProc.runningSeq = root.flowMetaSeq;
        flowMetaProc.running = true;
    }

    function applyMetaResponse(o, seq) {
        if (seq !== root.flowMetaSeq)
            return;
        if (typeof o.mode === "string" && o.mode.toUpperCase() !== root.currentMode)
            return;

        if (Array.isArray(o.options)) {
            const filtered = o.options.filter(s => typeof s === "string" && s.trim().length > 0);
            root.flowDocOptions = filtered;
        } else {
            root.flowDocOptions = [];
        }

        const nextWatchPath = (typeof o.path === "string" && o.path.length > 0) ? o.path : "";
        if (nextWatchPath !== root.flowOverviewWatchPath)
            root.flowOverviewWatchPath = nextWatchPath;

        const nextNotesPath = (typeof o.notesPath === "string" && o.notesPath.length > 0) ? o.notesPath : "";
        if (nextNotesPath !== root.flowNotesWatchPath)
            root.flowNotesWatchPath = nextNotesPath;

        const layout = (o.layout && typeof o.layout === "object") ? o.layout : ({});

        root.flowRoutineTitle = (typeof layout.routineTitle === "string") ? layout.routineTitle.trim() : "";
        root.flowRoutineDescription = (typeof layout.routineDescription === "string") ? layout.routineDescription.trim() : "";
        root.flowTasksTitle = (typeof layout.tasksTitle === "string") ? layout.tasksTitle.trim() : "";
        root.flowTasksDescription = (typeof layout.tasksDescription === "string") ? layout.tasksDescription.trim() : "";
        root.flowNotesTitle = (typeof layout.notesTitle === "string") ? layout.notesTitle.trim() : "";
        root.flowModeDescription = (typeof layout.modeDescription === "string") ? layout.modeDescription.trim() : "";
        if (layout.optionDescriptions && typeof layout.optionDescriptions === "object") {
            const descMap = {};
            for (const k of Object.keys(layout.optionDescriptions)) {
                const v = layout.optionDescriptions[k];
                if (typeof v === "string" && v.trim().length > 0)
                    descMap[String(k)] = v.trim();
            }
            root.flowOptionDescriptions = descMap;
        } else {
            root.flowOptionDescriptions = ({});
        }
        if (layout.optionButtons && typeof layout.optionButtons === "object") {
            const btnMap = {};
            for (const k of Object.keys(layout.optionButtons)) {
                const v = layout.optionButtons[k];
                if (Array.isArray(v)) {
                    const ids = v.filter(s => typeof s === "string" && s.trim().length > 0).map(s => s.trim());
                    if (ids.length > 0)
                        btnMap[String(k)] = ids;
                }
            }
            root.flowOptionButtons = btnMap;
        } else {
            root.flowOptionButtons = ({});
        }
        requestNotesRefresh();

        if (Array.isArray(layout.inlineHeaders)) {
            const map = {};
            for (const h of layout.inlineHeaders) {
                if (h && typeof h.at === "number" && typeof h.title === "string" && h.title.trim().length > 0)
                    map[h.at] = h.title.trim();
            }
            root.flowInlineHeaders = map;
        } else {
            root.flowInlineHeaders = ({});
        }

        root.flowRoutineOptions = Array.isArray(layout.routineOptions)
            ? layout.routineOptions.filter(s => typeof s === "string" && s.trim().length > 0)
            : [];
        root.flowTasksOptions = Array.isArray(layout.tasksOptions)
            ? layout.tasksOptions.filter(s => typeof s === "string" && s.trim().length > 0)
            : [];
        root.flowRoutineGlobalIndices = Array.isArray(layout.routineGlobalIndices) ? layout.routineGlobalIndices : [];
        root.flowTasksGlobalIndices = Array.isArray(layout.tasksGlobalIndices) ? layout.tasksGlobalIndices : [];

        // Fallback: if grouping wasn't provided, render everything as "routine".
        if ((root.flowRoutineOptions.length + root.flowTasksOptions.length) === 0 && root.flowDocOptions.length > 0) {
            root.flowRoutineOptions = root.flowDocOptions;
            const indices = [];
            for (let i = 0; i < root.flowDocOptions.length; i++)
                indices.push(i);
            root.flowRoutineGlobalIndices = indices;
            root.flowTasksOptions = [];
            root.flowTasksGlobalIndices = [];
        }

        root.flowMetaAppliedSeq = seq;
        root.currentOption = root.normalizeOption(root.currentOption);
    }

    function optionsForMode(mode) {
        if (mode === root.currentMode && root.flowDocOptions.length > 0)
            return root.flowDocOptions;
        return ["…"];
    }

    function normalizeOption(option) {
        const opts = optionsForMode(currentMode);
        if (opts.indexOf(option) !== -1)
            return option;
        if (option.length > 0)
            return option;
        if (root.flowDocOptions.length > 0)
            return root.flowDocOptions[0];
        return "";
    }

    function optionDescriptionForIndex(globalIndex) {
        const key = String(globalIndex);
        const desc = root.flowOptionDescriptions[key];
        return (typeof desc === "string") ? desc.trim() : "";
    }

    function optionButtonsForIndex(globalIndex) {
        const key = String(globalIndex);
        const raw = root.flowOptionButtons[key];
        if (!Array.isArray(raw))
            return [];
        return raw.filter(s => typeof s === "string" && s.trim().length > 0);
    }

    readonly property int currentOptionGlobalIndex: {
        const idx = root.flowDocOptions.indexOf(root.currentOption);
        return idx >= 0 ? idx : -1;
    }

    readonly property var currentOptionButtons: root.currentOptionGlobalIndex >= 0
        ? root.optionButtonsForIndex(root.currentOptionGlobalIndex)
        : []

    function requestNotesRefresh() {
        if (root.currentMode.length === 0)
            return;
        flowNotesProc.runningSeq += 1;
        flowNotesProc.running = true;
    }

    onCurrentModeChanged: {
        clearFlowDocState();
        executedFile.updateExecuted();
        flowMetaDebounce.restart();
        // set_mode.sh writes the first substate before current_mode; re-read from disk.
        optionFile.reload();
        optionFileSyncTimer.restart();
    }

    Timer {
        id: flowMetaDebounce
        interval: 60
        repeat: false
        onTriggered: requestFlowMeta()
    }

    Process {
        id: flowMetaProc
        property int runningSeq: 0
        running: false
        // Same as neko_flow_env.sh → flow_launch_overrides.sh so NEKO_DOCUMENTS matches Hyprland keybinds.
        command: [
            "bash",
            "-c",
            "source \"$HOME/.local/share/neko-flow/lib/neko_flow_paths.sh\" 2>/dev/null; neko_flow_init_paths; exec python3 \"$1\" meta \"$2\"",
            "_",
            root.nekoFlowParserPath,
            root.currentMode
        ]
        stdout: StdioCollector {
            id: flowMetaStdout
            onStreamFinished: {
                const t = flowMetaStdout.text.trim();
                const seq = flowMetaProc.runningSeq;
                if (!t.length)
                    return;
                try {
                    const o = JSON.parse(t);
                    root.applyMetaResponse(o, seq);
                } catch (e) {
                }
            }
        }
    }

    readonly property string flowDocWatchResolvedPath: root.flowOverviewWatchPath.length > 0 ? root.flowOverviewWatchPath : `${root.nekoFlowConfigDir}/flow_modes.txt`

    onFlowOverviewWatchPathChanged: {
        flowOverviewReloadTimer.restart();
    }

    onFlowNotesWatchPathChanged: {
        requestNotesRefresh();
    }

    Process {
        id: flowNotesProc
        property int runningSeq: 0
        running: false
        command: [
            "bash",
            "-c",
            "source \"$HOME/.local/share/neko-flow/lib/neko_flow_paths.sh\" 2>/dev/null; neko_flow_init_paths; exec python3 \"$1\" notes \"$2\"",
            "_",
            root.nekoFlowParserPath,
            root.currentMode
        ]
        stdout: StdioCollector {
            id: flowNotesStdout
            onStreamFinished: {
                const seq = flowNotesProc.runningSeq;
                const t = flowNotesStdout.text.trim();
                if (!t.length)
                    return;
                try {
                    const o = JSON.parse(t);
                    if (seq !== flowNotesProc.runningSeq)
                        return;
                    if (typeof o.mode === "string" && o.mode.toUpperCase() !== root.currentMode)
                        return;
                    if (typeof o.notesPath === "string" && o.notesPath.length > 0)
                        root.flowNotesWatchPath = o.notesPath;
                    if (typeof o.notesBody === "string")
                        root.flowNotesBody = o.notesBody;
                    else
                        root.flowNotesBody = "";
                } catch (e) {
                }
            }
        }
    }

    Timer {
        id: flowNotesPollTimer
        interval: 1500
        repeat: true
        running: root.currentMode.length > 0 && !root.currentModeIsExtra
        onTriggered: requestNotesRefresh()
    }

    Timer {
        id: flowOverviewReloadTimer
        interval: 80
        repeat: false
        onTriggered: {
            flowOverviewDocWatch.reload();
            flowMetaDebounce.restart();
        }
    }

    FileView {
        id: flowOverviewDocWatch
        path: FileUtils.trimFileProtocol(root.flowDocWatchResolvedPath)
        watchChanges: true
        onFileChanged: {
            reload();
            if (root.flowOverviewWatchPath.length > 0)
                flowOverviewChangeTimer.restart();
        }
    }

    Timer {
        id: flowOverviewChangeTimer
        interval: 80
        repeat: false
        onTriggered: flowMetaDebounce.restart()
    }

    Column {
        id: contentColumn
        anchors.centerIn: parent
        spacing: 6

        Item {
            implicitWidth: flowBox.implicitWidth
            implicitHeight: flowBox.implicitHeight
            width: implicitWidth
            height: implicitHeight

            StyledDropShadow {
                target: flowBox
                visible: flowBox.visible
                opacity: flowBox.opacity
            }

            Rectangle {
                id: flowBox
                anchors.fill: parent
            visible: true
            opacity: 1
            color: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.08)
            radius: 20

            readonly property real flowHPad: 40
            readonly property real flowVPad: 14

            implicitWidth: Math.max(flowColumn.implicitWidth + flowHPad * 2, 280)
            implicitHeight: flowColumn.implicitHeight + flowVPad * 2

            Column {
                id: flowColumn
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: root.currentModeIsExtra ? root.currentMode : `${root.currentMode}`
                    color: root.currentModeIsExtra ? Appearance.colors.colError : Appearance.colors.colPrimary
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    visible: !root.currentModeIsExtra && root.flowModeDescription.length > 0
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    width: Math.min(implicitWidth, 420)
                    text: root.flowModeDescription
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.italic: true
                    color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.45)
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    id: flowRow
                    spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter

                    Repeater {
                        model: root.flowModes.length
                        delegate: Row {
                            spacing: 6

                            Item {
                                readonly property string mode: root.flowModes[index]
                                implicitWidth: modeLabel.implicitWidth
                                implicitHeight: modeLabel.implicitHeight

                                Text {
                                    id: modeLabel
                                    text: parent.mode
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.bold: (parent.mode === root.currentMode) && !root.currentModeIsExtra
                                    color: (parent.mode === root.currentMode) && !root.currentModeIsExtra
                                        ? Appearance.colors.colOnPrimaryContainer
                                        : ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.42)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: root.flowSelectMode(parent.mode)
                                }
                            }

                            Text {
                                visible: index !== root.flowModes.length - 1
                                text: "→"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.62)
                            }
                        }
                    }
                }

                Text {
                    visible: root.flowRoutineTitle.length > 0 || root.flowRoutineOptions.length > 0
                    text: root.flowRoutineTitle
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    font.capitalization: Font.Capitalize
                    color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.5)
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Column {
                    id: optionColumn
                    spacing: 2
                    visible: root.flowRoutineOptions.length > 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    Repeater {
                        model: root.flowRoutineOptions.length

                        Column {
                            id: routineRow
                            required property int index
                            spacing: 2
                            anchors.horizontalCenter: parent.horizontalCenter

                            readonly property string modelData: (index >= 0 && index < root.flowRoutineOptions.length)
                                ? String(root.flowRoutineOptions[index]) : ""
                            readonly property int globalIndex: (index >= 0 && index < root.flowRoutineGlobalIndices.length)
                                ? root.flowRoutineGlobalIndices[index] : -1
                            readonly property string optionDesc: globalIndex >= 0
                                ? root.optionDescriptionForIndex(globalIndex) : ""
                            readonly property var optionButtons: globalIndex >= 0
                                ? root.optionButtonsForIndex(globalIndex) : []
                            readonly property bool active: modelData === root.currentOption

                            Text {
                                visible: routineRow.globalIndex >= 0
                                         && root.flowInlineHeaders[routineRow.globalIndex] !== undefined
                                         && String(root.flowInlineHeaders[routineRow.globalIndex]).trim().length > 0
                                text: routineRow.globalIndex >= 0
                                    ? String(root.flowInlineHeaders[routineRow.globalIndex] || "")
                                    : ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                font.capitalization: Font.Capitalize
                                color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.5)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitWidth: routineOptionRow.implicitWidth
                                implicitHeight: routineOptionRow.implicitHeight

                                Row {
                                    id: routineOptionRow
                                    spacing: 8
                                    anchors.centerIn: parent

                                    Text {
                                        id: routineOptionText
                                        readonly property bool executed: routineRow.modelData === root.executedOption && root.executedTimestamp.length > 0
                                        text: (routineRow.active ? "• " : "  ")
                                            + routineRow.modelData
                                            + (routineRow.optionDesc.length > 0 ? " - " + routineRow.optionDesc : "")
                                            + (executed ? " (" + root.executedTimestamp + ")" : "")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.bold: routineRow.active
                                        font.italic: routineRow.optionDesc.length > 0
                                        color: executed
                                            ? Appearance.colors.colError
                                            : (routineRow.active
                                                ? Appearance.colors.colOnPrimaryContainer
                                                : ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.35))
                                    }

                                    Repeater {
                                        model: routineRow.active ? routineRow.optionButtons.length : 0

                                        Rectangle {
                                            required property int index
                                            radius: 10
                                            color: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.22)
                                            border.color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.35)
                                            border.width: 1
                                            implicitWidth: flowBtnLabel.implicitWidth + 16
                                            implicitHeight: flowBtnLabel.implicitHeight + 8

                                            readonly property string buttonId: routineRow.optionButtons[index]

                                            Text {
                                                id: flowBtnLabel
                                                anchors.centerIn: parent
                                                text: parent.buttonId
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                font.weight: Font.Medium
                                                color: Appearance.colors.colOnPrimaryContainer
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.flowClickButton(parent.buttonId)
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: routineOptionText
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.flowSelectOption(routineRow.modelData)
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root.flowTasksTitle.length > 0 || root.flowTasksOptions.length > 0
                    text: root.flowTasksTitle
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    font.capitalization: Font.Capitalize
                    color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.5)
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Column {
                    id: tasksColumn
                    visible: root.flowTasksOptions.length > 0
                    spacing: 2
                    anchors.horizontalCenter: parent.horizontalCenter

                    Repeater {
                        model: root.flowTasksOptions.length

                        Column {
                            id: taskRow
                            spacing: 2
                            anchors.horizontalCenter: parent.horizontalCenter

                            readonly property string modelData: (index >= 0 && index < root.flowTasksOptions.length)
                                ? String(root.flowTasksOptions[index]) : ""
                            readonly property int globalIndex: (index >= 0 && index < root.flowTasksGlobalIndices.length)
                                ? root.flowTasksGlobalIndices[index] : -1
                            readonly property string optionDesc: globalIndex >= 0
                                ? root.optionDescriptionForIndex(globalIndex) : ""
                            readonly property var optionButtons: globalIndex >= 0
                                ? root.optionButtonsForIndex(globalIndex) : []
                            readonly property bool active: modelData === root.currentOption

                            Text {
                                visible: taskRow.globalIndex >= 0
                                         && root.flowInlineHeaders[taskRow.globalIndex] !== undefined
                                         && String(root.flowInlineHeaders[taskRow.globalIndex]).trim().length > 0
                                text: taskRow.globalIndex >= 0
                                    ? String(root.flowInlineHeaders[taskRow.globalIndex] || "")
                                    : ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                font.capitalization: Font.Capitalize
                                color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.5)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitWidth: taskOptionRow.implicitWidth
                                implicitHeight: taskOptionRow.implicitHeight

                                Row {
                                    id: taskOptionRow
                                    spacing: 8
                                    anchors.centerIn: parent

                                    Text {
                                        id: taskOptionText
                                        readonly property bool executed: taskRow.modelData === root.executedOption && root.executedTimestamp.length > 0
                                        text: (taskRow.active ? "• " : "  ")
                                            + taskRow.modelData
                                            + (taskRow.optionDesc.length > 0 ? " - " + taskRow.optionDesc : "")
                                            + (executed ? " (" + root.executedTimestamp + ")" : "")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.bold: taskRow.active
                                        font.italic: taskRow.optionDesc.length > 0
                                        color: executed
                                            ? Appearance.colors.colError
                                            : (taskRow.active
                                                ? Appearance.colors.colOnPrimaryContainer
                                                : ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.35))
                                    }

                                    Repeater {
                                        model: taskRow.active ? taskRow.optionButtons.length : 0

                                        Rectangle {
                                            required property int index
                                            radius: 10
                                            color: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.22)
                                            border.color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.35)
                                            border.width: 1
                                            implicitWidth: flowBtnLabel.implicitWidth + 16
                                            implicitHeight: flowBtnLabel.implicitHeight + 8

                                            readonly property string buttonId: taskRow.optionButtons[index]

                                            Text {
                                                id: flowBtnLabel
                                                anchors.centerIn: parent
                                                text: parent.buttonId
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                font.weight: Font.Medium
                                                color: Appearance.colors.colOnPrimaryContainer
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.flowClickButton(parent.buttonId)
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: taskOptionText
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.flowSelectOption(taskRow.modelData)
                                }
                            }
                        }
                    }
                }

                Item {
                    visible: root.flowNotesBody.length > 0
                    implicitWidth: notesBlock.implicitWidth
                    implicitHeight: notesBlock.implicitHeight
                    anchors.horizontalCenter: parent.horizontalCenter

                    Column {
                        id: notesBlock
                        spacing: 4
                        width: 260

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.flowNotesTitle.length > 0 ? root.flowNotesTitle : "Notes"
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            font.capitalization: Font.Capitalize
                            color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.5)
                        }

                        Text {
                            id: notesBodyText
                            width: parent.width
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignLeft
                            maximumLineCount: 12
                            elide: Text.ElideRight
                            text: root.flowNotesBody
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.italic: true
                            color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.42)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: 10
                        cursorShape: Qt.IBeamCursor
                        acceptedButtons: Qt.LeftButton
                        onDoubleClicked: root.flowOpenNotesInSublime()
                    }
                }

                Text {
                    visible: root.currentModeIsExtra
                    text: `Default flow: ${root.flowModes.join(" → ")}`
                    color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.55)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
    }

    FileView {
        id: optionFile
        path: `${root.nekoFlowConfigDir}/current_option`
        watchChanges: true

        // After reload(), FileView text can still be stale for a tick; Qt.callLater is not enough (see MaterialThemeLoader).
        function applyOptionFromDisk() {
            const raw = optionFile.text().trim();
            // Trust disk + normalizeOption (unknown non-empty labels are kept). Do not restart meta here:
            // that ran on every keypress when flowDocOptions lagged hardcoded modeOptions and fought cycling.
            root.currentOption = root.normalizeOption(raw);
        }

        onLoaded: applyOptionFromDisk()
        onFileChanged: {
            reload();
            optionFileSyncTimer.restart();
        }
    }

    Timer {
        id: optionFileSyncTimer
        interval: 80
        repeat: false
        onTriggered: optionFile.applyOptionFromDisk()
    }

    FileView {
        id: executedFile
        path: `${root.nekoFlowConfigDir}/flow_executed.json`
        watchChanges: true

        function updateExecuted() {
            let data = {};
            const raw = executedFile.text().trim();
            if (raw.length > 0) {
                try {
                    data = JSON.parse(raw);
                } catch (e) {
                    data = {};
                }
            }
            const entry = data[root.currentMode];
            if (entry && typeof entry.option === "string") {
                root.executedOption = entry.option;
                root.executedTimestamp = typeof entry.ts === "string" ? entry.ts : "";
            } else {
                root.executedOption = "";
                root.executedTimestamp = "";
            }
        }

        onLoaded: updateExecuted()
        onFileChanged: {
            reload();
            executedFileSyncTimer.restart();
        }
    }

    Timer {
        id: executedFileSyncTimer
        interval: 80
        repeat: false
        onTriggered: executedFile.updateExecuted()
    }

    Component.onCompleted: {
        flowModesFile.parseFlowModes();
        executedFile.updateExecuted();
        flowMetaDebounce.restart();
        requestNotesRefresh();
    }
}