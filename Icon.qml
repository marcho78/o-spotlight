import QtQuick
import QtQuick.Shapes
import "Icons.js" as Icons

// One of O-Spotlight's line icons (Icons.js), crisp at any size.
Item {
  id: icon

  property string name: ""
  property color color: "white"
  // Stroke width on the 24-unit grid the icons are drawn on.
  property real weight: 1.7

  implicitWidth: 24
  implicitHeight: 24

  Shape {
    anchors.fill: parent
    visible: icon.name !== ""
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: icon.color
      fillColor: "transparent"
      strokeWidth: icon.weight * icon.width / 24
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      scale: Qt.size(icon.width / 24, icon.height / 24)
      PathSvg { path: Icons.path(icon.name) }
    }
  }
}
