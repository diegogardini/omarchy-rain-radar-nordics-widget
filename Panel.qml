import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "MapModel.js" as MapModel

Panel {
  id: root
  moduleName: "io.github.diegogardini.omarchy-rain-radar-denmark-widget"
  ipcTarget: moduleName
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property var samples: []
  property var weatherLocation: null
  property var ipLocation: null
  readonly property var automaticLocation: weatherLocation || ipLocation
  property var selection: null
  property var pendingSelection: null
  property bool selectionLoaded: false
  property bool savingSelection: false
  property bool pickingLocation: false
  property var draftLocation: null
  property string selectionError: ""
  property string locationError: ""
  readonly property color selectionColor: "#f6ad55"
  readonly property string locationSettingsKey: JSON.stringify([setting("latitude", ""), setting("longitude", ""), setting("locationName", "")])
  readonly property var effectiveSelection: selection && (selection.settingsKey === undefined || selection.settingsKey === locationSettingsKey) ? selection : null
  readonly property string selectionPath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/settings/rain-radar-location.json"
  property var activeLocation: null
  property string errorMessage: ""
  property bool loading: false
  property int locationProviderIndex: 0
  readonly property var locationProviders: [
    "https://get.geojs.io/v1/ip/geo.json",
    "https://ipwho.is/",
    "https://ipapi.co/json/"
  ]

  readonly property int refreshMinutes: Math.max(5, parseInt(setting("refreshMinutes", 5), 10) || 5)
  readonly property var currentSample: samples.length > 0 ? samples[0] : null
  readonly property string currentMm: currentSample ? Model.formatMm(currentSample.mm) : "—"
  readonly property string currentIntensity: currentSample ? Model.intensity(currentSample.mm) : "Waiting for data"
  readonly property string barLabel: "󰖗 " + currentMm
  readonly property string tooltip: activeLocation
    ? ((activeLocation.name || "Current position") + ": " + currentMm + " mm/h · " + currentIntensity)
    : "Rain radar · locating…"

  function configuredOverride() {
    var latitude = Model.finiteNumber(setting("latitude", ""))
    var longitude = Model.finiteNumber(setting("longitude", ""))
    if (latitude === null || longitude === null) return null
    return { name: String(setting("locationName", "")) || "Configured position", latitude: latitude, longitude: longitude }
  }

  function resolveLocation() {
    if (!selectionLoaded) return
    var location = Model.forecastLocation(effectiveSelection, configuredOverride(), automaticLocation)
    if (location) { useLocation(location); return }
    activeLocation = null
    samples = []
    ensureAutomaticLocation()
  }

  function ensureAutomaticLocation() {
    if (automaticLocation) return
    if (!locationProc.running) {
      locationProviderIndex = 0
      startLocationLookup()
    }
  }

  function startLocationLookup() {
    if (locationProviderIndex >= locationProviders.length) {
      locationError = "Automatic location unavailable. You can still choose a position on the map."
      if (!activeLocation) { errorMessage = locationError; loading = false }
      return
    }
    locationError = ""
    if (!activeLocation) loading = true
    locationProc.command = ["curl", "-fsS", "--max-time", "7", locationProviders[locationProviderIndex]]
    locationProc.running = true
  }

  function useLocation(location) {
    location = MapModel.namedLocation(location)
    if (Model.locationKey(activeLocation) !== Model.locationKey(location)) samples = []
    activeLocation = location
    if (!Model.inCoverage(location.latitude, location.longitude)) {
      errorMessage = "This position is outside DMI's Denmark coverage."
      samples = []
      loading = false
      return
    }
    fetchRain()
  }

  function fetchRain() {
    if (!activeLocation || !Model.inCoverage(activeLocation.latitude, activeLocation.longitude) || rainProc.running) return
    errorMessage = ""
    loading = true
    var start = new Date()
    var end = new Date(start.getTime() + 12 * 60 * 60 * 1000)
    var url = "https://opendataapi.dmi.dk/v1/forecastedr/collections/harmonie_dini_sf/position"
      + "?coords=" + encodeURIComponent("POINT(" + activeLocation.longitude + " " + activeLocation.latitude + ")")
      + "&crs=crs84&parameter-name=rain-precipitation-rate&f=GeoJSON"
      + "&datetime=" + encodeURIComponent(start.toISOString() + "/" + end.toISOString())
    rainProc.command = ["curl", "-fsSL", "--max-time", "10", url]
    rainProc.requestLocationKey = Model.locationKey(activeLocation)
    rainProc.responseText = ""
    rainProc.running = true
  }

  function refresh() {
    locationFile.reload()
    resolveLocation()
  }

  function open() { controller.show(); refresh() }

  function beginLocationPicker() {
    draftLocation = activeLocation
    selectionError = ""
    pickingLocation = true
    Qt.callLater(function() { picker.forceActiveFocus() })
    ensureAutomaticLocation()
  }

  function saveSelection(automatic) {
    if (savingSelection || (!automatic && (!draftLocation || !Model.inCoverage(draftLocation.latitude, draftLocation.longitude)))) return
    pendingSelection = automatic ? { mode: "automatic" } : { mode: "selected", location: draftLocation }
    pendingSelection.settingsKey = locationSettingsKey
    savingSelection = true
    selectionError = ""
    selectionFile.setText(JSON.stringify(pendingSelection, null, 2) + "\n")
  }

  // Allow the settings fingerprint and effective selection bindings to settle.
  onSettingsChanged: if (selectionLoaded) Qt.callLater(resolveLocation)
  onOpenedChanged: if (!opened) pickingLocation = false

  FileView {
    id: selectionFile
    path: root.selectionPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.selection = Model.parseSelection(text())
      root.selectionLoaded = true
      root.resolveLocation()
    }
    onLoadFailed: {
      root.selectionLoaded = true
      root.resolveLocation()
    }
    onSaved: {
      root.selection = root.pendingSelection
      root.savingSelection = false
      root.pickingLocation = false
      keyCatcher.forceActiveFocus()
      root.resolveLocation()
    }
    onSaveFailed: {
      root.savingSelection = false
      root.selectionError = "Could not save the location. Try again."
    }
  }

  FileView {
    id: locationFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { root.weatherLocation = Model.parseWeatherLocation(text()); root.resolveLocation() }
    onLoadFailed: { root.weatherLocation = null; root.resolveLocation() }
  }

  Process {
    id: locationProc
    property string responseText: ""
    onRunningChanged: if (running) responseText = ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: locationProc.responseText = text
    }
    onExited: function(exitCode) {
      var location = exitCode === 0 ? Model.parseIpLocation(responseText) : null
      if (location) {
        root.ipLocation = location
        // A lookup started for the blue dot must not replace a manual choice.
        if (!root.activeLocation) root.resolveLocation()
        return
      }
      if (root.weatherLocation) return
      root.locationProviderIndex++
      Qt.callLater(root.startLocationLookup)
    }
  }

  Process {
    id: rainProc
    property string requestLocationKey: ""
    property string responseText: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: rainProc.responseText = text
    }
    onExited: function(exitCode) {
      // Discard a response for the previous city, then fetch the latest choice.
      if (requestLocationKey !== Model.locationKey(root.activeLocation)) {
        Qt.callLater(root.fetchRain)
        return
      }
      if (exitCode !== 0) {
        root.errorMessage = "Could not load the DMI forecast."
      } else {
        var parsed = Model.parseDmiForecast(responseText)
        if (parsed.length === 0) root.errorMessage = "DMI returned no forecast values."
        else { root.samples = parsed; root.errorMessage = "" }
      }
      root.loading = false
    }
  }

  Timer {
    interval: root.refreshMinutes * 60 * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function status(): string {
      return JSON.stringify({
        loading: root.loading,
        provider: root.locationProviderIndex,
        location: root.activeLocation,
        automaticLocation: root.automaticLocation,
        selection: root.selection,
        samples: root.samples.length,
        currentMm: root.currentMm,
        error: root.errorMessage,
        locationProcess: locationProc.running,
        rainProcess: rainProc.running
      })
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(560))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.pickingLocation
      onCloseRequested: root.close()
      onReturnRequested: root.refresh()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) { if (text.toLowerCase() === "c") root.beginLocationPicker() }

      Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: content
          width: parent.width
          spacing: Style.space(14)

          Row {
            width: parent.width
            spacing: Style.space(12)

            Column {
              width: parent.width - refreshButton.width - parent.spacing
              spacing: Style.space(4)

              Text {
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: root.activeLocation ? (root.activeLocation.name || "Current position") : "Finding current position…"
                color: root.barForeground
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Text {
                text: root.currentMm + " mm/h  ·  " + root.currentIntensity
                color: root.samples.length ? Color.accent : Util.alpha(root.barForeground, 0.65)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
            }

            Text {
              id: refreshButton
              text: root.loading ? "󰦖" : "󰑐"
              color: root.barForeground
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              anchors.verticalCenter: parent.verticalCenter

              RotationAnimator on rotation {
                running: root.loading
                from: 0; to: 360; duration: 800; loops: Animation.Infinite
              }
              TapHandler { enabled: !root.loading; onTapped: root.refresh() }
              HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
          }

          Button {
            visible: !root.pickingLocation
            text: "Change location"
            iconText: "󰍎"
            tooltipText: "Change location (C)"
            foreground: root.barForeground
            onClicked: root.beginLocationPicker()
          }

          Column {
            id: picker
            width: parent.width
            spacing: Style.space(10)
            visible: root.pickingLocation
            enabled: !root.savingSelection
            Keys.onEscapePressed: { root.pickingLocation = false; keyCatcher.forceActiveFocus() }
            Keys.onReturnPressed: root.saveSelection(false)

            Text {
              width: parent.width
              text: "Click a city name or any point on the map."
              color: root.barForeground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            LocationMap {
              width: parent.width
              height: Style.space(330)
              foreground: root.barForeground
              background: Color.background
              accent: root.selectionColor
              fontFamily: Style.font.family
              fontSize: Style.space(11)
              automaticLocation: root.automaticLocation
              selectedLocation: root.draftLocation
              onLocationPicked: function(location) { root.draftLocation = location }
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: root.automaticLocation
                ? "● Blue: " + (root.automaticLocation.name || "Automatic location") + (root.weatherLocation ? " (Weather settings)" : " (approximate IP location)") + (Model.inCoverage(root.automaticLocation.latitude, root.automaticLocation.longitude) ? "" : " · outside map")
                : (root.locationError || "Finding automatic location…")
              color: "#369bff"
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: root.draftLocation ? "◎ " + root.draftLocation.name + " · " + root.draftLocation.latitude.toFixed(4) + ", " + root.draftLocation.longitude.toFixed(4) : "Choose a forecast location"
              color: root.selectionColor
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              width: parent.width
              visible: root.selectionError !== ""
              text: root.selectionError
              wrapMode: Text.WordWrap
              color: Color.urgent
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            Flow {
              width: parent.width
              spacing: Style.space(8)
              Button {
                text: root.savingSelection ? "Saving…" : "Use selected location"
                enabled: root.draftLocation !== null && Model.inCoverage(root.draftLocation.latitude, root.draftLocation.longitude)
                foreground: root.barForeground
                bordered: true
                focusable: true
                onClicked: root.saveSelection(false)
              }
              Button {
                text: "Use automatic location"
                foreground: root.barForeground
                focusable: true
                onClicked: root.saveSelection(true)
              }
              Button {
                text: "Cancel"
                foreground: root.barForeground
                focusable: true
                onClicked: { root.pickingLocation = false; keyCatcher.forceActiveFocus() }
              }
            }
          }

          RainGraph {
            width: parent.width
            height: Style.space(235)
            samples: root.samples
            foreground: root.barForeground
            accent: Color.accent
            visible: !root.pickingLocation && root.samples.length > 0
          }

          Text {
            width: parent.width
            visible: !root.pickingLocation && root.errorMessage !== ""
            text: root.errorMessage
            wrapMode: Text.WordWrap
            color: Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }

          Text {
            width: parent.width
            visible: !root.pickingLocation && root.samples.length > 0
            text: "Rainfall in mm/h · Nonlinear scale emphasizes light rain. Hourly forecast samples."
            wrapMode: Text.WordWrap
            color: Util.alpha(root.barForeground, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            text: "Data: DMI"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.underline: sourceHover.hovered
            TapHandler { onTapped: Quickshell.execDetached(["xdg-open", "https://www.dmi.dk"]) }
            HoverHandler { id: sourceHover; cursorShape: Qt.PointingHandCursor }
          }
        }
      }
    }
  }
}
