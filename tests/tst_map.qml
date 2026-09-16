import QtQuick
import QtTest
import ".." as Rain
import "../MapModel.js" as MapModel

Item {
  width: 560; height: 330
  // Matches LocationMap.qml's zoomBar height (22) + mapArea's topMargin (6):
  // the clickable/drawable map area is offset below the zoom button row.
  readonly property int mapAreaOffsetY: 28
  readonly property int mapAreaWidth: width
  readonly property int mapAreaHeight: height - mapAreaOffsetY
  Rain.LocationMap {
    id: map
    anchors.fill: parent
    onLocationPicked: function(location) { selectedLocation = location }
  }
  SignalSpy { id: picks; target: map; signalName: "locationPicked" }
  TestCase {
    name: "LocationMap"
    when: windowShown
    function init() { picks.clear(); map.selectedLocation = null; map.zoomedCountry = "" }
    function test_mapClick() {
      var point = MapModel.project(66.0, 15.0, mapAreaWidth, mapAreaHeight)
      var x = Math.round(point.x), y = Math.round(point.y)
      var expected = MapModel.unproject(x, y, mapAreaWidth, mapAreaHeight)
      mouseClick(map, x, y + mapAreaOffsetY)
      compare(picks.count, 1)
      compare(map.selectedLocation.name, expected.name)
      fuzzyCompare(map.selectedLocation.latitude, expected.latitude, 0.00001)
      fuzzyCompare(map.selectedLocation.longitude, expected.longitude, 0.00001)
    }
    function test_cityLabel() {
      var city = MapModel.cities[6] // Gothenburg
      var point = MapModel.project(city.latitude, city.longitude, mapAreaWidth, mapAreaHeight)
      mouseClick(map, point.x - 25, point.y - 12 + mapAreaOffsetY)
      compare(picks.count, 1)
      compare(map.selectedLocation.name, city.name)
      compare(map.selectedLocation.latitude, city.latitude)
    }
    function test_outsideBounds() {
      mouseClick(map, 2, 2 + mapAreaOffsetY)
      compare(picks.count, 0)
    }
    function test_keyboardNudge() {
      // Click an empty spot (away from any city label's hit area) first to
      // give the map area keyboard focus (matching real usage: focus
      // follows a click), then nudge relative to wherever that click landed.
      var point = MapModel.project(66.0, 15.0, mapAreaWidth, mapAreaHeight)
      var x = Math.round(point.x), y = Math.round(point.y)
      mouseClick(map, x, y + mapAreaOffsetY)
      compare(picks.count, 1)
      var before = map.selectedLocation
      keyClick(Qt.Key_Right)
      compare(picks.count, 2)
      fuzzyCompare(map.selectedLocation.longitude, before.longitude + 0.05, 0.00001)
      fuzzyCompare(map.selectedLocation.latitude, before.latitude, 0.00001)
    }
    function test_zoomedClickUsesCountryBounds() {
      map.zoomedCountry = "Denmark"
      compare(map.activeView.bounds.west, MapModel.countryViews.Denmark.bounds.west)
      var point = MapModel.project(56.0, 10.5, mapAreaWidth, mapAreaHeight, MapModel.countryViews.Denmark)
      var x = Math.round(point.x), y = Math.round(point.y)
      var expected = MapModel.unproject(x, y, mapAreaWidth, mapAreaHeight, MapModel.countryViews.Denmark)
      mouseClick(map, x, y + mapAreaOffsetY)
      compare(picks.count, 1)
      fuzzyCompare(map.selectedLocation.latitude, expected.latitude, 0.00001)
      fuzzyCompare(map.selectedLocation.longitude, expected.longitude, 0.00001)
    }
  }
}
