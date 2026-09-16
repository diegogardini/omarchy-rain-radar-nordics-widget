pragma ComponentBehavior: Bound
import QtQuick
import "MapModel.js" as MapModel
import "MapData.js" as MapData

Item {
  id: root
  property var automaticLocation: null
  property var selectedLocation: null
  property color foreground: "#e2e8f0"
  property color background: "#18232e"
  property color accent: "#f6ad55"
  property string fontFamily: "sans-serif"
  property real fontSize: 11
  readonly property color automaticColor: "#369bff"
  // "" means the full Nordics view; otherwise a key into MapModel.countryViews.
  // Denmark's small footprint within the full view makes precise picking
  // hard there, so a zoomed-in country view gives finer click precision.
  property string zoomedCountry: ""
  readonly property var activeView: root.zoomedCountry === "" ? null : MapModel.countryViews[root.zoomedCountry]
  signal locationPicked(var location)

  function translucent(color, opacity) { return Qt.rgba(color.r, color.g, color.b, opacity) }

  Row {
    id: zoomBar
    height: 22
    spacing: 4
    Repeater {
      model: ["Nordics", "Denmark", "Norway", "Sweden", "Finland"]
      delegate: Rectangle {
        id: zoomButton
        required property string modelData
        readonly property bool active: modelData === "Nordics" ? root.zoomedCountry === "" : root.zoomedCountry === modelData
        width: zoomLabel.implicitWidth + 12
        height: zoomBar.height
        radius: 4
        color: active ? root.accent : root.translucent(root.foreground, 0.08)
        border.color: root.translucent(root.foreground, 0.25)
        Text {
          id: zoomLabel
          anchors.centerIn: parent
          text: zoomButton.modelData
          color: zoomButton.active ? root.background : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Math.max(9, root.fontSize - 1)
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.zoomedCountry = (zoomButton.modelData === "Nordics" ? "" : zoomButton.modelData)
        }
      }
    }
  }

  Rectangle {
    id: mapArea
    anchors.top: zoomBar.bottom
    anchors.topMargin: 6
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom

    activeFocusOnTab: true
    Keys.onPressed: function(event) {
      var view = root.activeView ? root.activeView.bounds : MapModel.bounds
      var location = root.selectedLocation || root.automaticLocation || { latitude: (view.south + view.north) / 2, longitude: (view.west + view.east) / 2 }
      var latitude = location.latitude
      var longitude = location.longitude
      if (event.key === Qt.Key_Left) longitude -= 0.05
      else if (event.key === Qt.Key_Right) longitude += 0.05
      else if (event.key === Qt.Key_Up) latitude += 0.05
      else if (event.key === Qt.Key_Down) latitude -= 0.05
      else return
      root.locationPicked(MapModel.areaLocation(
        Number(Math.max(view.south, Math.min(view.north, latitude)).toFixed(5)),
        Number(Math.max(view.west, Math.min(view.east, longitude)).toFixed(5))))
      event.accepted = true
    }

    color: root.background
    radius: 8
    clip: true
    border.color: mapArea.activeFocus ? root.accent : root.translucent(root.foreground, 0.2)

    Canvas {
      id: map
      anchors.fill: parent
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      Connections {
        target: root
        function onForegroundChanged() { map.requestPaint() }
        function onBackgroundChanged() { map.requestPaint() }
        function onActiveViewChanged() { map.requestPaint() }
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
              var p = MapModel.project(ring[k][1], ring[k][0], width, height, root.activeView)
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
        mapArea.forceActiveFocus()
        var location = MapModel.unproject(mouse.x, mouse.y, width, height, root.activeView)
        if (location) root.locationPicked(location)
      }
    }

    Repeater {
      model: MapModel.cities
      delegate: Item {
        id: city
        required property var modelData
        readonly property var point: MapModel.project(modelData.latitude, modelData.longitude, mapArea.width, mapArea.height, root.activeView)
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
      readonly property var point: root.automaticLocation ? MapModel.project(root.automaticLocation.latitude, root.automaticLocation.longitude, mapArea.width, mapArea.height, root.activeView) : ({ x: -100, y: -100 })
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
      readonly property var point: root.selectedLocation ? MapModel.project(root.selectedLocation.latitude, root.selectedLocation.longitude, mapArea.width, mapArea.height, root.activeView) : ({ x: -100, y: -100 })
      visible: root.selectedLocation !== null
      x: point.x - width / 2; y: point.y - height / 2
      width: 28; height: 28; radius: 14
      color: "transparent"
      border.color: root.accent; border.width: 3
    }
  }
}
