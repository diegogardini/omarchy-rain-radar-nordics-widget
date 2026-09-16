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
  property color noCoverageColor: "#e05252"
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
    width: parent.width
    height: 22
    spacing: 4
    Repeater {
      id: zoomRepeater
      model: ["Nordics", "Denmark", "Norway", "Sweden", "Finland"]
      delegate: Rectangle {
        id: zoomButton
        required property string modelData
        readonly property bool active: modelData === "Nordics" ? root.zoomedCountry === "" : root.zoomedCountry === modelData
        function activate() { root.zoomedCountry = (zoomButton.modelData === "Nordics" ? "" : zoomButton.modelData) }
        width: (zoomBar.width - zoomBar.spacing * (zoomRepeater.count - 1)) / zoomRepeater.count
        height: zoomBar.height
        radius: 4
        activeFocusOnTab: true
        color: active ? root.accent : root.translucent(root.foreground, 0.08)
        border.color: zoomButton.activeFocus ? root.foreground : root.translucent(root.foreground, 0.25)
        border.width: zoomButton.activeFocus ? 2 : 1
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            zoomButton.activate()
            event.accepted = true
          }
        }
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
          onClicked: { zoomButton.forceActiveFocus(); zoomButton.activate() }
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
      root.locationPicked(MapModel.pointLocation(
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

        // Project the radar coverage boundary once, reused by the tint,
        // its hole, and the dashed outline below.
        var coverageRing = MapData.radarCoverage.rings[0]
        var coveragePoints = []
        for (var m = 0; m < coverageRing.length; m++)
          coveragePoints.push(MapModel.project(coverageRing[m][1], coverageRing[m][0], width, height, root.activeView))

        // The view's own bounds rarely match the canvas's aspect ratio, so
        // viewport() letterboxes: the map only fills part of the canvas,
        // with empty margins to either side or above/below. Confine the
        // tint to that actual map rectangle (from the view's own corners),
        // not the full canvas — otherwise the coverage ring's real edge,
        // extrapolated through the empty margins with the same projection,
        // paints a confusing false boundary out there.
        var viewBounds = (root.activeView ? root.activeView.bounds : MapModel.bounds)
        var mapTopLeft = MapModel.project(viewBounds.north, viewBounds.west, width, height, root.activeView)
        var mapBottomRight = MapModel.project(viewBounds.south, viewBounds.east, width, height, root.activeView)

        // Qt Quick's Canvas doesn't honor fill(fillRule), so an "evenodd
        // hole" can't be punched via a compound path: fill the map
        // rectangle with the tint, then erase the covered region with a
        // destination-out composite instead. Drawn before the country
        // shapes so their own (semi-transparent) fill still renders
        // normally on top, inside or outside the tinted area.
        ctx.fillStyle = root.translucent(root.noCoverageColor, 0.16)
        ctx.fillRect(mapTopLeft.x, mapTopLeft.y, mapBottomRight.x - mapTopLeft.x, mapBottomRight.y - mapTopLeft.y)
        ctx.globalCompositeOperation = "destination-out"
        ctx.beginPath()
        for (m = 0; m < coveragePoints.length; m++) {
          if (m === 0) ctx.moveTo(coveragePoints[m].x, coveragePoints[m].y)
          else ctx.lineTo(coveragePoints[m].x, coveragePoints[m].y)
        }
        ctx.closePath()
        ctx.fill()
        ctx.globalCompositeOperation = "source-over"

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

        // Dashed outline of the coverage boundary itself, drawn last so
        // it's visible over both the tint and the country shapes. Clipped
        // to the same map rectangle as the tint, for the same reason.
        ctx.save()
        ctx.beginPath()
        ctx.rect(mapTopLeft.x, mapTopLeft.y, mapBottomRight.x - mapTopLeft.x, mapBottomRight.y - mapTopLeft.y)
        ctx.clip()
        ctx.beginPath()
        for (m = 0; m < coveragePoints.length; m++) {
          if (m === 0) ctx.moveTo(coveragePoints[m].x, coveragePoints[m].y)
          else ctx.lineTo(coveragePoints[m].x, coveragePoints[m].y)
        }
        ctx.closePath()
        ctx.strokeStyle = root.translucent(root.noCoverageColor, 0.7)
        ctx.lineWidth = 1
        ctx.setLineDash([3, 3])
        ctx.stroke()
        ctx.setLineDash([])
        ctx.restore()
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
