pragma ComponentBehavior: Bound
import QtQuick
import "MapModel.js" as MapModel
import "MapData.js" as MapData

Rectangle {
  id: root
  property var automaticLocation: null
  property var selectedLocation: null
  property color foreground: "#e2e8f0"
  property color background: "#18232e"
  property color accent: "#f6ad55"
  property string fontFamily: "sans-serif"
  property real fontSize: 11
  readonly property color automaticColor: "#369bff"
  signal locationPicked(var location)

  activeFocusOnTab: true
  Keys.onPressed: function(event) {
    var location = selectedLocation || automaticLocation || { latitude: 60.0, longitude: 15.0 }
    var latitude = location.latitude
    var longitude = location.longitude
    if (event.key === Qt.Key_Left) longitude -= 0.05
    else if (event.key === Qt.Key_Right) longitude += 0.05
    else if (event.key === Qt.Key_Up) latitude += 0.05
    else if (event.key === Qt.Key_Down) latitude -= 0.05
    else return
    root.locationPicked(MapModel.areaLocation(
      Number(Math.max(MapModel.bounds.south, Math.min(MapModel.bounds.north, latitude)).toFixed(5)),
      Number(Math.max(MapModel.bounds.west, Math.min(MapModel.bounds.east, longitude)).toFixed(5))))
    event.accepted = true
  }

  function translucent(color, opacity) { return Qt.rgba(color.r, color.g, color.b, opacity) }

  color: background
  radius: 8
  clip: true
  border.color: activeFocus ? accent : translucent(foreground, 0.2)

  Canvas {
    id: map
    anchors.fill: parent
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Connections {
      target: root
      function onForegroundChanged() { map.requestPaint() }
      function onBackgroundChanged() { map.requestPaint() }
    }
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      for (var i = 0; i < MapData.countries.length; i++) {
        var country = MapData.countries[i]
        ctx.fillStyle = root.translucent(root.foreground, country.covered ? 0.15 : 0.04)
        ctx.strokeStyle = root.translucent(root.foreground, country.covered ? 0.55 : 0.18)
        ctx.lineWidth = 1
        for (var j = 0; j < country.rings.length; j++) {
          var ring = country.rings[j]
          ctx.beginPath()
          for (var k = 0; k < ring.length; k++) {
            var p = MapModel.project(ring[k][1], ring[k][0], width, height)
            if (k === 0) ctx.moveTo(p.x, p.y)
            else ctx.lineTo(p.x, p.y)
          }
          ctx.closePath()
          ctx.fill()
          ctx.stroke()
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.CrossCursor
    onClicked: function(mouse) {
      root.forceActiveFocus()
      var location = MapModel.unproject(mouse.x, mouse.y, width, height)
      if (location) root.locationPicked(location)
    }
  }

  Repeater {
    model: MapModel.cities
    delegate: Item {
      id: city
      required property var modelData
      readonly property var point: MapModel.project(modelData.latitude, modelData.longitude, root.width, root.height)
      x: point.x
      y: point.y
      Rectangle {
        x: -2; y: -2; width: 4; height: 4; radius: 2
        color: root.foreground
      }
      Text {
        id: label
        x: city.modelData.dx - (city.modelData.align === "right" ? width : 0)
        y: city.modelData.dy - height / 2
        text: city.modelData.name
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        style: Text.Outline
        styleColor: root.background
        MouseArea {
          anchors.fill: parent
          anchors.margins: -3
          cursorShape: Qt.PointingHandCursor
          onClicked: root.locationPicked({ name: city.modelData.name, latitude: city.modelData.latitude, longitude: city.modelData.longitude })
        }
      }
    }
  }

  Rectangle {
    readonly property var point: root.automaticLocation ? MapModel.project(root.automaticLocation.latitude, root.automaticLocation.longitude, root.width, root.height) : ({ x: -100, y: -100 })
    visible: root.automaticLocation !== null
    x: point.x - width / 2; y: point.y - height / 2
    width: 22; height: 22; radius: 11
    color: root.translucent(root.automaticColor, 0.25)
    Rectangle {
      anchors.centerIn: parent
      width: 12; height: 12; radius: 6
      color: root.automaticColor
      border.color: "white"; border.width: 2
    }
  }

  Rectangle {
    readonly property var point: root.selectedLocation ? MapModel.project(root.selectedLocation.latitude, root.selectedLocation.longitude, root.width, root.height) : ({ x: -100, y: -100 })
    visible: root.selectedLocation !== null
    x: point.x - width / 2; y: point.y - height / 2
    width: 28; height: 28; radius: 14
    color: "transparent"
    border.color: root.accent; border.width: 3
  }
}
