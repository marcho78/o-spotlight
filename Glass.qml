import QtQuick
import QtQuick.Effects

// A Liquid Glass pane (from Stage Control, same author). Given the picture
// behind it (`backdrop`, a texture that covers `backdropSpace`), it shows that
// picture through: liquid bends it inward at the rim like a thick lens, with a
// specular rim lit from the top left (shaders/glass.frag); frosted is flat and
// more tinted, easier to read over busy windows. Without a backdrop, with the
// "solid" style, or if the shader can't load, it draws a solid pane with the
// same rim. Content goes inside, as children.
//
// style: "liquid", "frosted" or "solid".
Item {
  id: glass

  property real radius: height / 2
  property string style: "liquid"
  property bool dark: true
  property bool shadow: true
  property real shadowStrength: 1
  property bool hovered: false
  property bool pressed: false
  property bool selected: false
  property color selectedColor: "#0a84ff"
  property real selectedStrength: 0.78
  property color outlineColor: "transparent"
  property real outlineWidth: 0
  property Item backdrop: null
  property Item backdropSpace: null
  // How blurry the backdrop reads (a mip level; the backdrop may come
  // pre-blurred), how far the rim bends it, and how much tint lies on top.
  property real frost: style === "liquid" ? 1.6 : 3.2
  property real refraction: Math.min(12, Math.min(width, height) * 0.24)
  property real tintStrength: 1
  // A style's own colors instead of the neutral glass (-1 keeps the neutral):
  // the tint laid over the backdrop, the rim's strength, and the pane drawn
  // when there's no backdrop.
  property color tintColor: "black"
  property real tintAlpha: -1
  property real rimStrength: -1
  property color paneColor: "black"
  property real paneAlpha: -1

  readonly property bool refracting: style !== "solid" && !!backdrop && !!backdropSpace && lens.status !== ShaderEffect.Error
  readonly property bool frosted: style === "frosted"

  default property alias content: inner.data

  RectangularShadow {
    anchors.fill: parent
    radius: glass.radius
    offset: Qt.vector2d(0, 10)
    blur: 36
    spread: -4
    color: Qt.rgba(0, 0, 0, (glass.style === "solid" ? 0.40 : glass.dark ? 0.34 : 0.18) * glass.shadowStrength)
    visible: glass.shadow && glass.opacity > 0
  }

  ShaderEffect {
    id: lens
    anchors.fill: parent
    visible: glass.refracting

    property var backdrop: glass.backdrop
    property size itemSize: Qt.size(width, height)
    property real radius: glass.radius
    property real bevel: Math.max(4, Math.min(width, height) * 0.34)
    property real refraction: glass.frosted ? 0 : glass.refraction
    property real frost: glass.frosted ? glass.frost + 0.8 : glass.frost
    property real rim: glass.rimStrength >= 0 ? glass.rimStrength : glass.frosted ? 0.55 : 1.0
    property real flip: 0
    property vector4d area: Qt.vector4d(0, 0, 1, 1)
    property vector4d tint: glass.tintAlpha >= 0
      ? Qt.vector4d(glass.tintColor.r, glass.tintColor.g, glass.tintColor.b, glass.tintAlpha)
      : glass.dark
      ? Qt.vector4d(0.07, 0.07, 0.09, (glass.frosted ? 0.58 : 0.34) * glass.tintStrength)
      : Qt.vector4d(0.98, 0.98, 1.0, (glass.frosted ? 0.66 : 0.42) * glass.tintStrength)
    property vector4d fill: glass.selected ? Qt.vector4d(glass.selectedColor.r, glass.selectedColor.g, glass.selectedColor.b, glass.selectedStrength)
      : glass.pressed ? Qt.vector4d(0, 0, 0, 0.16)
      : glass.hovered ? Qt.vector4d(1, 1, 1, 0.12)
      : Qt.vector4d(0, 0, 0, 0)

    fragmentShader: Qt.resolvedUrl("shaders/glass.frag.qsb")
  }

  // Where the pane sits over the backdrop, followed every frame while it
  // shows (panes ride on animated parents).
  FrameAnimation {
    running: glass.refracting && glass.visible && glass.opacity > 0
    onTriggered: glass.updateArea()
  }

  function updateArea() {
    if (!backdropSpace) return
    var a = glass.mapToItem(backdropSpace, 0, 0)
    var b = glass.mapToItem(backdropSpace, glass.width, glass.height)
    var w = Math.max(1, backdropSpace.width)
    var h = Math.max(1, backdropSpace.height)
    var next = Qt.vector4d(a.x / w, a.y / h, (b.x - a.x) / w, (b.y - a.y) / h)
    var now = lens.area
    if (Math.abs(next.x - now.x) + Math.abs(next.y - now.y) + Math.abs(next.z - now.z) + Math.abs(next.w - now.w) > 0.00001)
      lens.area = next
  }

  // The drawn pane, for when there is nothing to refract.
  Item {
    id: drawn
    anchors.fill: parent
    visible: !glass.refracting

    readonly property real bodyAlpha: glass.style === "solid" ? 0.97 : 0.9
    readonly property color topColor: glass.dark ? Qt.rgba(0.20, 0.20, 0.22, 1) : Qt.rgba(1, 1, 1, 1)
    readonly property color bottomColor: glass.dark ? Qt.rgba(0.13, 0.13, 0.15, 1) : Qt.rgba(0.95, 0.95, 0.97, 1)
    readonly property real lift: glass.pressed ? -0.04 : glass.hovered ? 0.06 : 0

    Rectangle {
      anchors.fill: parent
      radius: glass.radius
      visible: glass.paneAlpha >= 0
      color: Qt.rgba(glass.paneColor.r, glass.paneColor.g, glass.paneColor.b, Math.max(0, glass.paneAlpha))
    }

    Rectangle {
      anchors.fill: parent
      radius: glass.radius
      visible: glass.paneAlpha < 0
      gradient: Gradient {
        GradientStop {
          position: 0
          color: glass.selected ? Qt.rgba(glass.selectedColor.r, glass.selectedColor.g, glass.selectedColor.b, Math.min(1, glass.selectedStrength + 0.07))
            : Qt.rgba(drawn.topColor.r, drawn.topColor.g, drawn.topColor.b, Math.min(1, drawn.bodyAlpha + drawn.lift))
        }
        GradientStop {
          position: 1
          color: glass.selected ? Qt.rgba(glass.selectedColor.r, glass.selectedColor.g, glass.selectedColor.b, glass.selectedStrength)
            : Qt.rgba(drawn.bottomColor.r, drawn.bottomColor.g, drawn.bottomColor.b, Math.min(1, drawn.bodyAlpha + 0.04 + drawn.lift))
        }
      }
    }

    // Rim: a hairline, brighter across the top half.
    Rectangle {
      anchors.fill: parent
      radius: glass.radius
      color: "transparent"
      border.width: 1
      border.color: glass.dark ? Qt.rgba(1, 1, 1, glass.style === "solid" ? 0.10 : 0.14) : Qt.rgba(0, 0, 0, 0.10)
    }
    Item {
      anchors.left: parent.left
      anchors.right: parent.right
      height: Math.max(glass.radius, parent.height * 0.5)
      clip: true
      Rectangle {
        width: glass.width
        height: glass.height
        radius: glass.radius
        color: "transparent"
        border.width: 1
        border.color: glass.dark ? Qt.rgba(1, 1, 1, glass.style === "solid" ? 0.16 : 0.30) : Qt.rgba(1, 1, 1, 0.9)
      }
    }
  }

  // Selection ring, drawn over the glass.
  Rectangle {
    anchors.fill: parent
    radius: glass.radius
    color: "transparent"
    border.width: glass.outlineWidth
    border.color: glass.outlineColor
    visible: glass.outlineWidth > 0
  }

  Item {
    id: inner
    anchors.fill: parent
  }
}
