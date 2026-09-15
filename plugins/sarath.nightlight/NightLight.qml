import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Persistent night light control.
//
// The built-in hyprsunset toggle only nudges the running process, so a reboot
// forgets it. This widget instead writes an always-active profile into
// ~/.config/hypr/hyprsunset.conf (via apply.sh): once enabled, hyprsunset is
// told to use it immediately and re-reads it at every login, so the on/off +
// warmth choice itself survives reboots and logouts. State lives in this
// widget's inline shell.json entry (also re-applied by the post-boot hook).

Panel {
  id: root
  moduleName: "sarath.nightlight"
  ipcTarget: "sarath.nightlight"
  manageIpc: false

  readonly property string applyScript: Quickshell.env("HOME") + "/.config/omarchy/plugins/sarath.nightlight/apply.sh"

  // Persisted settings (this widget's inline shell.json entry).
  readonly property bool nightEnabled: setting("enabled", false) === true
  readonly property int nightTemperature: clampTemperature(setting("temperature", 4000))

  // Live temperature reported by the running hyprsunset.
  property int liveTemperature: 0
  property bool liveKnown: false
  readonly property bool liveNight: liveKnown && liveTemperature > 0 && liveTemperature < 6000

  readonly property bool effectiveNight: nightEnabled || liveNight

  readonly property string statusLabel: {
    if (nightEnabled) return "On at " + nightTemperature + " K"
    if (liveNight) return "On at " + liveTemperature + " K"
    return "Off"
  }

  readonly property string statusNote: nightEnabled
    ? "Stays on until you turn it off"
    : "Warmth disabled \u00b7 identity restored"

  function clampTemperature(value) {
    var n = Math.round(Number(value))
    if (!isFinite(n)) return 4000
    return Math.max(2500, Math.min(6500, n))
  }

  function refreshStatus() {
    if (!statusProc.running) statusProc.running = true
  }

  function applySettings() {
    if (applyProc.running) return
    applyProc.command = [root.applyScript,
      root.nightEnabled ? "1" : "0",
      String(root.nightTemperature)]
    applyProc.running = true
  }

  function saveSettings(next) {
    root.settings = Object.assign({}, root.settings, next)
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, root.settings)
    }
  }

  function setEnabled(value) {
    saveSettings({ enabled: !!value })
    applySettings()
  }

  function setTemperature(value) {
    var temp = clampTemperature(value)
    saveSettings({ temperature: temp, enabled: true })
    applySettings()
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }

    function status(): string {
      return JSON.stringify({
        enabled: root.nightEnabled,
        temperature: root.nightTemperature,
        liveTemperature: root.liveKnown ? root.liveTemperature : null
      })
    }

    function setEnabled(value: bool): string {
      root.setEnabled(Boolean(value))
      return root.nightEnabled ? "enabled" : "disabled"
    }

    function setTemperature(value: int): string {
      root.setTemperature(Number(value))
      return String(root.nightTemperature)
    }
  }

  onOpenedChanged: {
    if (opened) refreshStatus()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statusProc
    command: ["hyprctl", "hyprsunset", "temperature"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var match = String(text || "").match(/[0-9]+/)
        root.liveTemperature = match ? Number(match[0]) : 0
        root.liveKnown = true
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.liveTemperature = 0
        root.liveKnown = true
      }
    }
  }

  Process {
    id: applyProc
    onExited: function() {
      root.refreshStatus()
      statusRetry.restart()
    }
  }

  // hyprsunset re-applies its stored profile at the end of its boot, which can
  // temporarily override our live value — re-probe shortly after any exit.
  Timer {
    id: statusRetry
    interval: 1200
    onTriggered: root.refreshStatus()
  }

  Timer {
    interval: 5000
    running: root.opened
    repeat: true
    onTriggered: root.refreshStatus()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf186"
    active: root.effectiveNight
    tooltipText: root.effectiveNight ? ("Night Light \u00b7 " + (root.liveNight ? root.liveTemperature : root.nightTemperature) + " K") : "Night Light \u00b7 Off"
    onPressed: function(button) {
      if (button === Qt.RightButton) root.setEnabled(!root.nightEnabled)
      else root.toggle()
    }
    onWheelMoved: function(delta) {
      if (!root.nightEnabled) return
      root.setTemperature(root.nightTemperature + (delta > 0 ? 100 : -100))
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher

    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // ---------- Hero: moon icon · title · status ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: "\uf186"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 200 } }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Night Light"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.statusLabel.toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        // ---------- On/off ----------
        Toggle {
          id: enableToggle
          width: parent.width
          label: "Night light"
          description: root.statusNote
          checked: root.nightEnabled
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          onClicked: root.setEnabled(!root.nightEnabled)
        }

        // ---------- Warmth ----------
        PanelSeparator {
          foreground: root.bar.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(10)

          Item {
            width: parent.width
            implicitHeight: Math.max(warmthHeader.implicitHeight, warmthLabel.implicitHeight)

            PanelSectionHeader {
              id: warmthHeader
              text: "WARMTH"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: warmthLabel
              textFormat: Text.PlainText
              text: root.nightEnabled ? root.nightTemperature + " K" : "Disabled"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Item {
            width: parent.width
            implicitHeight: root.nightEnabled ? warmthSlider.implicitHeight + Style.spacing.controlGap : 0
            visible: root.nightEnabled

            PanelSlider {
              id: warmthSlider
              bar: root.bar
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              minimum: 2500
              maximum: 6500
              step: 100
              integer: true
              value: root.nightTemperature
              onReleased: function(value) { root.setTemperature(value) }
            }
          }

          Text {
            width: parent.width
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            textFormat: Text.PlainText
            text: "Lower is warmer. Changes apply now and are remembered across reboots and logouts."
            color: Qt.darker(root.bar.foreground, 1.65)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
      }
    }
  }
}