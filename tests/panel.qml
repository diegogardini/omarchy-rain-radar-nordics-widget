import QtQuick
import Quickshell
import qs.Commons
import "Plugin" as Rain

ShellRoot {
  id: test
  property int phase: -1
  property int ticks: 0
  function check(value, message) { if (!value) { console.error("FAIL: " + message); Qt.exit(1) } }
  Rain.Panel { id: panel }
  Timer {
    interval: 100
    running: true
    repeat: true
    onTriggered: {
      test.ticks++
      if (test.ticks > 80) { console.error("Timeout phase " + test.phase); Qt.exit(1); return }
      if (test.phase === -1) {
        panel.useLocation({name: "Selected position", latitude: 55.63, longitude: 12.60})
        test.check(panel.activeLocation.name === "55.6300°N, 12.6000°E", "legacy generic label resolves to a coordinate label")
        test.check(panel.activeLocation.latitude === 55.63 && panel.activeLocation.longitude === 12.60, "coordinate label preserves forecast coordinates")
        panel.weatherLocation = {name: "Odense", latitude: 55.4038, longitude: 10.4024}
        panel.resolveLocation()
        test.phase = 0
      }
      if (test.phase === 0 && panel.selectionLoaded && panel.samples.length > 0) {
        panel.beginLocationPicker()
        panel.draftLocation = {name: "Aarhus", latitude: 56.1629, longitude: 10.2039}
        panel.saveSelection(false)
        test.phase++
      } else if (test.phase === 1 && !panel.savingSelection) {
        test.check(panel.activeLocation.name === "Aarhus", "selection applies")
        panel.beginLocationPicker()
        panel.draftLocation = {name: "Copenhagen", latitude: 55.6761, longitude: 12.5683}
        panel.saveSelection(false)
        test.phase++
      } else if (test.phase === 2 && !panel.savingSelection && !panel.loading) {
        test.check(panel.activeLocation.name === "Copenhagen", "latest city wins")
        test.check(panel.samples.length > 0 && panel.samples[0].mm === 0, "old Aarhus response discarded")
        panel.settings = {latitude: "57.0488", longitude: "9.9217", locationName: "Aalborg"}
        Qt.callLater(function() {
          test.check(panel.activeLocation.name === "Aalborg", "edited coordinate settings supersede saved map choice")
          panel.draftLocation = {name: "Invalid", latitude: 90, longitude: 11}
          panel.saveSelection(false)
          test.check(!panel.savingSelection, "out-of-coverage keyboard choice rejected")
          panel.saveSelection(true)
          test.phase++
        })
      } else if (test.phase === 3 && !panel.savingSelection && !panel.loading) {
        test.check(panel.selection.mode === "automatic", "automatic choice persists")
        test.check(panel.activeLocation === panel.automaticLocation, "automatic position restored")
        panel.open()
        panel.beginLocationPicker()
        panel.draftLocation = {name: "55.6300°N, 12.6000°E", latitude: 55.63, longitude: 12.60}
        test.phase++
        test.ticks = 0
      } else if (test.phase === 4 && test.ticks > 10) {
        for (var i = 0; i < panel.data.length; i++) {
          var child = panel.data[i]
          if (child.contentWidth !== undefined && child.contentItem) {
            child.contentItem[0].grabToImage(function(result) {
              if (Quickshell.env("RAIN_RADAR_TEST_CAPTURE")) test.check(result.saveToFile(Quickshell.env("RAIN_RADAR_TEST_CAPTURE")), "save screenshot")
              console.log("PASS: selection, rapid changes, persistence, automatic reset, settings edits, invalid coordinates, full picker render")
              Qt.quit()
            })
            test.phase++
            return
          }
        }
        console.error("Popup not found")
        Qt.exit(1)
      }
    }
  }
}
