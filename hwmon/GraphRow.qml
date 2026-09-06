import QtQuick

// One labelled live-graph row: label + current value on the first line,
// sparkline(s) beneath. `series` is a list of normalized 0..1 sample
// arrays and `colors` parallels it (e.g. two series for the NET graph's
// down/up split).
Item {
    id: graphRow

    property string label: ""
    property string valueText: ""
    property color valueColor: "#c5c9c5"
    property color labelColor: "#c8c093"
    property var series: []
    property var colors: []
    property string fontFamily: "monospace"
    property real graphHeight: 56

    height: labelRow.height + 4 + graphRow.graphHeight

    Item {
        id: labelRow
        anchors.left: parent.left
        anchors.right: parent.right
        height: 18

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: graphRow.label
            color: graphRow.labelColor
            font.family: graphRow.fontFamily
            font.pixelSize: 10
            font.letterSpacing: 2
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: graphRow.valueText
            color: graphRow.valueColor
            font.family: graphRow.fontFamily
            font.pixelSize: 10
            font.letterSpacing: 1
        }
    }

    Sparkline {
        anchors.top: labelRow.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        height: graphRow.graphHeight
        series: graphRow.series
        colors: graphRow.colors
    }
}