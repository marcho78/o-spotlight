import QtQuick

// Under a style's field: the results as a list or a grid (whichever
// Spotlight.qml says: Applications and Files can be grids), the welcome the
// first time, or a line saying there's nothing. The style gives the row, the
// tile, the section header and the welcome their look.
Item {
  id: body

  property var ui: null
  property Component rowDelegate: null
  property Component tileDelegate: null
  property Component sectionDelegate: null
  property Component gridHeader: null
  property Component welcome: null
  property real spacing: 2
  property int orientation: ListView.Vertical
  property real listTopMargin: 0
  property real listBottomMargin: 0
  // A list that runs sideways is this tall (the Command strip's cards).
  property real sidewaysHeight: 128
  // "No results found." and the like.
  property string emptyFont: "sans-serif"
  property int emptySize: 14
  property color emptyColor: "gray"

  readonly property alias list: list
  readonly property alias grid: grid
  readonly property bool welcoming: !!ui && ui.showOnboarding
  readonly property real welcomeHeight: welcomeLoader.item ? welcomeLoader.item.implicitHeight : 0
  // How tall it would like to be.
  readonly property real contentHeight: welcoming ? welcomeHeight
    : ui && ui.gridView ? ui.gridHeight
    : ui && ui.emptyShown ? 60
    : orientation === ListView.Vertical ? list.contentHeight + listTopMargin + listBottomMargin : sidewaysHeight

  function reveal(index) {
    if (!ui || index < 0) return
    if (ui.gridView) {
      var pos = ui.tilePositions[index]
      if (!pos) return
      var bottom = pos.y + (pos.h || ui.gridMetrics.tileHeight)
      if (pos.y < grid.contentY) grid.contentY = Math.max(0, pos.y - 8)
      else if (bottom > grid.contentY + grid.height) grid.contentY = bottom - grid.height + 8
    } else {
      list.positionViewAtIndex(index, ListView.Contain)
    }
  }

  ListView {
    id: list
    anchors.fill: parent
    visible: !!body.ui && !body.ui.gridView && !body.welcoming
    orientation: body.orientation
    clip: true
    model: body.ui ? body.ui.resultsModel : null
    delegate: body.rowDelegate
    spacing: body.spacing
    topMargin: body.listTopMargin
    bottomMargin: body.listBottomMargin
    cacheBuffer: 2400
    reuseItems: false
    boundsBehavior: Flickable.StopAtBounds
    interactive: orientation === ListView.Vertical ? contentHeight > height : contentWidth > width
    section.property: body.sectionDelegate ? "sectionTitle" : ""
    section.criteria: ViewSection.FullString
    section.delegate: body.sectionDelegate
  }

  Flickable {
    id: grid
    anchors.fill: parent
    visible: !!body.ui && body.ui.gridView && !body.welcoming
    clip: true
    contentHeight: body.ui ? body.ui.gridHeight : 0
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Repeater {
      model: body.ui && body.ui.gridView && body.gridHeader ? body.ui.gridDecor : []
      delegate: body.gridHeader
    }
    Repeater {
      model: body.ui && body.ui.gridView ? body.ui.resultsModel : null
      delegate: body.tileDelegate
    }
  }

  Loader {
    id: welcomeLoader
    width: parent.width
    active: body.welcoming && !!body.welcome
    sourceComponent: body.welcome
  }

  Text {
    anchors.centerIn: parent
    visible: !!body.ui && body.ui.emptyShown && !body.welcoming
    text: body.ui ? body.ui.emptyText : ""
    textFormat: Text.PlainText
    color: body.emptyColor
    font.family: body.emptyFont
    font.pixelSize: body.emptySize
  }
}
