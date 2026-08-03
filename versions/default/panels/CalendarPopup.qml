import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: calPopup
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-calendar"

    readonly property int barBottom: 35
    readonly property int gap: 8
    property bool settingsVisible: false
    property bool countrySelectorVisible: false
    property bool subdivisionSelectorVisible: false
    property string countryQuery: ""
    property string subdivisionQuery: ""
    property int countryKeyboardIndex: 0
    property int subdivisionKeyboardIndex: 0
    property string hoveredHolidayDate: ""
    readonly property string detailDate: hoveredHolidayDate || root.selectedCalendarDate
    readonly property var detailHolidays: root.holidays.holidaysFor(detailDate)

    function vibrantHolidayColor(themeColor) {
        var hue = themeColor.hsvHue
        if (hue < 0) hue = 0
        return Qt.hsva(hue, Math.max(0.82, themeColor.hsvSaturation),
            Math.max(0.95, themeColor.hsvValue), 1.0)
    }

    function holidayTypeLabel(holiday) {
        if (holiday.type === "bank-closure")
            return holiday.description + " · India-wide recurring bank-branch closure"
        if (holiday.scope === "national") return "National public holiday"
        if (holiday.scope === "regional")
            return (holiday.subdivisionName || "Regional") + " public holiday"
        return "Bank holiday"
    }

    function closeSelectors() {
        countrySelectorVisible = false
        subdivisionSelectorVisible = false
        countryQuery = ""
        subdivisionQuery = ""
    }

    function toggleSettings() {
        settingsVisible = !settingsVisible
        closeSelectors()
        if (settingsVisible) root.holidays.requestCountries()
    }

    property real reveal: root.calendarVisible ? 1 : 0
    visible: root.calendarVisible
    WlrLayershell.keyboardFocus: root.calendarVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.calendarVisible = false
    }

    Rectangle {
        id: card
        width: calPopup.settingsVisible ? 340 : 280
        height: col.implicitHeight + 24
        radius: root.pillRadius
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round((parent.width - width) / 2)
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: calPopup.reveal
        focus: root.calendarVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.calendarVisible = false;
                event.accepted = true;
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // ── header: month name + navigation chevrons ──
            Item {
                width: parent.width
                height: 24

                // ‹ previous month / back from settings
                Rectangle {
                    id: prevBtn
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: root.tileRadius
                    color: "transparent"
                    UiText {
                        anchors.centerIn: parent
                        text: "‹"   // ‹
                        color: prevMa.containsMouse ? root.seal : root.sumi
                        font.family: root.mono; font.pixelSize: 16
                    }
                    MouseArea {
                        id: prevMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (calPopup.settingsVisible) calPopup.toggleSettings()
                            else root.calendarMonthOffset--
                        }
                    }
                }

                // month + year — click to jump back to today
                UiText {
                    anchors.centerIn: parent
                    text: calPopup.settingsVisible ? "HOLIDAY REGION"
                        : root.calendarMonthName + "  " + root.calendarYear
                    color: monthMa.containsMouse && root.calendarMonthOffset !== 0 ? root.seal : root.ink
                    font.family: root.mono
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                    MouseArea {
                        id: monthMa
                        anchors.fill: parent; anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: !calPopup.settingsVisible && root.calendarMonthOffset !== 0
                            ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (!calPopup.settingsVisible) root.calendarMonthOffset = 0
                    }
                }

                Rectangle {
                    anchors.right: nextBtn.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: root.tileRadius
                    color: settingsMa.containsMouse || calPopup.settingsVisible ? root.pill : "transparent"
                    UiText {
                        anchors.centerIn: parent
                        text: "󰒓"
                        color: settingsMa.containsMouse || calPopup.settingsVisible ? root.indigo : root.sumi
                        font.family: root.mono
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: settingsMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calPopup.toggleSettings()
                    }
                }

                // › next month
                Rectangle {
                    id: nextBtn
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: root.tileRadius
                    color: "transparent"
                    visible: !calPopup.settingsVisible
                    UiText {
                        anchors.centerIn: parent
                        text: "›"   // ›
                        color: nextMa.containsMouse ? root.seal : root.sumi
                        font.family: root.mono; font.pixelSize: 16
                    }
                    MouseArea {
                        id: nextMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.calendarMonthOffset++
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── weekday headers ──
            Row {
                width: parent.width
                visible: !calPopup.settingsVisible
                Repeater {
                    model: ["SU","MO","TU","WE","TH","FR","SA"]
                    delegate: Item {
                        required property string modelData
                        required property int index
                        width: parent.width / 7
                        height: 20
                        UiText {
                            anchors.centerIn: parent
                            text: modelData
                            color: (index === 0 || index === 6) ? root.seal : root.inkDeep
                            opacity: (index === 0 || index === 6) ? 0.85 : 0.7
                            font.family: root.mono
                            font.pixelSize: 10
                            font.letterSpacing: 2
                        }
                    }
                }
            }

            // ── day grid ──
            Grid {
                columns: 7
                rowSpacing: 2
                columnSpacing: 0
                width: parent.width
                visible: !calPopup.settingsVisible
                Repeater {
                    model: root.calendarCells
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: parent.width / 7
                        height: 28

                        readonly property int dayOfWeek: index % 7
                        readonly property bool isCurrentMonth: modelData.day !== 0
                        readonly property bool isToday: modelData.today
                        readonly property string isoDate: isCurrentMonth ? root.calendarIsoDate(modelData.day) : ""
                        readonly property var dayHolidays: root.holidays.holidaysFor(isoDate)
                        readonly property var dayMarkers: root.holidays.markerClassesFor(isoDate)
                        readonly property bool isHoliday: dayHolidays.length > 0
                        readonly property bool isSelected: isCurrentMonth && root.selectedCalendarDate === isoDate

                        readonly property color textColor: {
                            if (isToday) return root.seal.hsvValue < 0.5 ? root.ink : root.paper;
                            if (!isCurrentMonth) return root.inkDeep;
                            return (dayOfWeek === 0 || dayOfWeek === 6) ? root.seal : root.ink;
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            color: root.seal
                            visible: isToday
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            border.color: root.seal; border.width: 1
                            color: "transparent"
                            visible: isSelected && !isToday
                        }

                        UiText {
                            anchors.centerIn: parent
                            text: modelData.day === 0 ? "" : modelData.day
                            color: textColor
                            opacity: isCurrentMonth ? 1.0 : 0.35
                            font.family: root.mono
                            font.pixelSize: 12
                            font.weight: isToday ? Font.Medium : Font.Light
                        }

                        Item {
                            anchors.fill: parent
                            visible: isCurrentMonth && isHoliday && root.holidays.showInGrid
                            Repeater {
                                model: dayMarkers
                                delegate: Rectangle {
                                    required property string modelData
                                    required property int index
                                    readonly property color markerColor: modelData === "regional"
                                        ? calPopup.vibrantHolidayColor(root.color03)
                                        : calPopup.vibrantHolidayColor(modelData === "bank-closure"
                                            ? root.color02 : root.indigo)
                                    anchors.centerIn: parent
                                    width: 19 + index * 3
                                    height: width
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: markerColor
                                    border.width: Math.max(1.5, root.pillBorderW)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: isCurrentMonth
                            enabled: isCurrentMonth
                            cursorShape: isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                root.selectedDay = modelData.day
                                root.selectedCalendarDate = isoDate
                            }
                            onEntered: {
                                if (isHoliday) calPopup.hoveredHolidayDate = isoDate
                            }
                            onExited: {
                                if (calPopup.hoveredHolidayDate === isoDate) calPopup.hoveredHolidayDate = ""
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: holidayDetails.implicitHeight + 12
                radius: root.tileRadius
                color: root.pill
                visible: !calPopup.settingsVisible && calPopup.detailHolidays.length > 0

                Column {
                    id: holidayDetails
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 2

                    Repeater {
                        model: calPopup.detailHolidays
                        delegate: Column {
                            required property var modelData
                            width: parent.width
                            spacing: 1
                            UiText {
                                width: parent.width
                                text: modelData.name
                                color: root.ink
                                font.family: root.mono
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                wrapMode: Text.Wrap
                            }
                            UiText {
                                width: parent.width
                                text: calPopup.holidayTypeLabel(modelData)
                                    + " · " + modelData.countryName
                                color: root.sumi
                                opacity: 0.75
                                font.family: root.mono
                                font.pixelSize: 9
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }

            UiText {
                width: parent.width
                visible: !calPopup.settingsVisible && root.holidays.status === "error"
                text: root.holidays.errorCode === "country-ambiguous"
                    ? "Select a holiday country in Astra settings"
                    : "Holiday data unavailable"
                color: root.sumi
                opacity: 0.7
                horizontalAlignment: Text.AlignHCenter
                font.family: root.mono
                font.pixelSize: 9
                wrapMode: Text.Wrap
            }

            Column {
                width: parent.width
                visible: calPopup.settingsVisible
                spacing: 8

                UiText {
                    width: parent.width
                    text: "Country"
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: root.tileRadius
                    color: root.pill
                    border.color: root.pillBorder
                    border.width: root.pillBorderW
                    UiText {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.holidays.countryStatus === "loading" ? "Loading countries…"
                            : (root.holidays.countryStatus === "error" ? "Country list unavailable"
                            : (root.holidays.countrySelectionMode === "auto"
                                ? "Automatic" + (root.holidays.detectedCountryName
                                    ? " — " + root.holidays.detectedCountryName : " — unresolved")
                                : (root.holidays.effectiveCountryName ||
                                    root.holidays.configuredCountryCode || "Select country")))
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 11
                    }
                    UiText {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: calPopup.countrySelectorVisible ? "▴" : "▾"
                        color: root.indigo
                        font.family: root.mono
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            calPopup.countrySelectorVisible = !calPopup.countrySelectorVisible
                            calPopup.subdivisionSelectorVisible = false
                            if (calPopup.countrySelectorVisible) countrySearch.forceActiveFocus()
                        }
                    }
                }

                Column {
                    width: parent.width
                    visible: calPopup.countrySelectorVisible
                    spacing: 4
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: root.tileRadius
                        color: root.paper
                        border.color: root.pillBorder
                        border.width: root.pillBorderW
                        UiText {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: countrySearch.text.length === 0
                            text: "Search countries…"
                            color: root.sumi
                            opacity: 0.55
                            font.family: root.mono
                            font.pixelSize: 10
                        }
                        TextInput {
                            id: countrySearch
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            text: calPopup.countryQuery
                            color: root.ink
                            selectionColor: root.indigo
                            font.family: root.mono
                            font.pixelSize: 10
                            onTextChanged: {
                                calPopup.countryQuery = text
                                calPopup.countryKeyboardIndex = 0
                            }
                            Keys.onPressed: function(event) {
                                var count = countryList.count
                                if (event.key === Qt.Key_Down) {
                                    calPopup.countryKeyboardIndex = Math.min(count - 1,
                                        calPopup.countryKeyboardIndex + 1)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Up) {
                                    calPopup.countryKeyboardIndex = Math.max(0,
                                        calPopup.countryKeyboardIndex - 1)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    var item = countryList.model[calPopup.countryKeyboardIndex]
                                    if (item) {
                                        root.holidays.selectCountry(item.code)
                                        calPopup.closeSelectors()
                                    }
                                    event.accepted = true
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: 26
                        radius: root.tileRadius
                        color: autoCountryMa.containsMouse ? root.pill : "transparent"
                        UiText {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Use system timezone"
                            color: root.holidays.countrySelectionMode === "auto" ? root.indigo : root.ink
                            font.family: root.mono
                            font.pixelSize: 10
                        }
                        MouseArea {
                            id: autoCountryMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.holidays.useDetectedCountry()
                                calPopup.closeSelectors()
                            }
                        }
                    }
                    ListView {
                        id: countryList
                        width: parent.width
                        height: Math.min(contentHeight, 116)
                        clip: true
                        model: root.holidays.filteredCountries(calPopup.countryQuery)
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: countryList.width
                            height: 26
                            radius: root.tileRadius
                            color: index === calPopup.countryKeyboardIndex ? root.pill : "transparent"
                            UiText {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name + "  " + modelData.code
                                color: root.ink
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: calPopup.countryKeyboardIndex = index
                                onClicked: {
                                    root.holidays.selectCountry(modelData.code)
                                    calPopup.closeSelectors()
                                }
                            }
                        }
                    }
                }

                UiText {
                    width: parent.width
                    text: "State / Province / Region"
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: root.tileRadius
                    color: root.pill
                    opacity: root.holidays.subdivisionStatus === "loading" ? 0.55
                        : (root.holidays.hasSubdivisions ? 1 : 0.45)
                    UiText {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.holidays.subdivisionStatus === "loading" ? "Loading regions…"
                            : (root.holidays.effectiveSubdivisionName || (root.holidays.hasSubdivisions
                                ? "National holidays only" : "No supported regions"))
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.holidays.hasSubdivisions
                            && root.holidays.subdivisionStatus === "ready"
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            calPopup.subdivisionSelectorVisible = !calPopup.subdivisionSelectorVisible
                            calPopup.countrySelectorVisible = false
                            if (calPopup.subdivisionSelectorVisible) subdivisionSearch.forceActiveFocus()
                        }
                    }
                }

                Column {
                    width: parent.width
                    visible: calPopup.subdivisionSelectorVisible && root.holidays.hasSubdivisions
                    spacing: 4
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: root.tileRadius
                        color: root.paper
                        UiText {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: subdivisionSearch.text.length === 0
                            text: "Search regions…"
                            color: root.sumi
                            opacity: 0.55
                            font.family: root.mono
                            font.pixelSize: 10
                        }
                        TextInput {
                            id: subdivisionSearch
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            text: calPopup.subdivisionQuery
                            color: root.ink
                            font.family: root.mono
                            font.pixelSize: 10
                            onTextChanged: {
                                calPopup.subdivisionQuery = text
                                calPopup.subdivisionKeyboardIndex = 0
                            }
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: 26
                        radius: root.tileRadius
                        color: noRegionMa.containsMouse ? root.pill : "transparent"
                        UiText {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: "National holidays only"
                            color: root.holidays.effectiveSubdivisionCode ? root.ink : root.indigo
                            font.family: root.mono
                            font.pixelSize: 10
                        }
                        MouseArea {
                            id: noRegionMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.holidays.selectSubdivision("")
                                calPopup.closeSelectors()
                            }
                        }
                    }
                    ListView {
                        id: subdivisionList
                        width: parent.width
                        height: Math.min(contentHeight, 104)
                        clip: true
                        model: root.holidays.filteredSubdivisions(calPopup.subdivisionQuery)
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: subdivisionList.width
                            height: 26
                            radius: root.tileRadius
                            color: index === calPopup.subdivisionKeyboardIndex ? root.pill : "transparent"
                            UiText {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name + "  " + modelData.code
                                color: root.ink
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: calPopup.subdivisionKeyboardIndex = index
                                onClicked: {
                                    root.holidays.selectSubdivision(modelData.code)
                                    calPopup.closeSelectors()
                                }
                            }
                        }
                    }
                }

                UiText {
                    width: parent.width
                    text: "Show"
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Repeater {
                    model: [
                        { key: "national", label: "National public holidays" },
                        { key: "regional", label: "State / regional public holidays" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 27
                        radius: root.tileRadius
                        color: categoryMa.containsMouse ? root.pill : "transparent"
                        readonly property bool checked: modelData.key === "national"
                            ? root.holidays.showNational : root.holidays.showRegional
                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 15
                            height: 15
                            radius: root.styleRadiusSmall ? 3 : 5
                            color: parent.checked ? root.indigo : "transparent"
                            border.color: parent.checked ? root.indigo : root.pillBorder
                            border.width: Math.max(1, root.pillBorderW)
                            UiText {
                                anchors.centerIn: parent
                                visible: parent.parent.checked
                                text: "✓"
                                color: root.paper
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                        }
                        UiText {
                            anchors.left: parent.left
                            anchors.leftMargin: 24
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: root.ink
                            font.family: root.mono
                            font.pixelSize: 10
                        }
                        MouseArea {
                            id: categoryMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.key === "national")
                                    root.holidays.setCategories(!parent.checked,
                                        root.holidays.showRegional)
                                else
                                    root.holidays.setCategories(root.holidays.showNational,
                                        !parent.checked)
                            }
                        }
                    }
                }

                UiText {
                    width: parent.width
                    text: !root.holidays.showNational && !root.holidays.showRegional
                        ? "No public holiday categories selected"
                        : root.holidays.detectionMessage
                    color: root.holidays.selectionWarning ? root.seal : root.sumi
                    opacity: 0.8
                    font.family: root.mono
                    font.pixelSize: 9
                    wrapMode: Text.Wrap
                }

                UiText {
                    width: parent.width
                    visible: root.holidays.effectiveCountryCode === "IN"
                    text: "Banks closed on second and fourth Saturdays are shown automatically."
                    color: root.sumi
                    opacity: 0.8
                    font.family: root.mono
                    font.pixelSize: 9
                    wrapMode: Text.Wrap
                }

                UiText {
                    width: parent.width
                    visible: root.holidays.selectionWarning.length > 0
                    text: root.holidays.selectionWarning
                    color: root.seal
                    font.family: root.mono
                    font.pixelSize: 9
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
