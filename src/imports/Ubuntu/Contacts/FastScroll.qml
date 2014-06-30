/****************************************************************************
**
** Copyright (C) 2011 Nokia Corporation and/or its subsidiary(-ies).
** Copyright (C) 2014 Canonical Ltda
** All rights reserved.
** Contact: Nokia Corporation (qt-info@nokia.com)
**
** This file is part of the Qt Components project.
**
** $QT_BEGIN_LICENSE:BSD$
** You may use this file under the terms of the BSD license as follows:
**
** "Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are
** met:
**   * Redistributions of source code must retain the above copyright
**     notice, this list of conditions and the following disclaimer.
**   * Redistributions in binary form must reproduce the above copyright
**     notice, this list of conditions and the following disclaimer in
**     the documentation and/or other materials provided with the
**     distribution.
**   * Neither the name of Nokia Corporation and its Subsidiary(-ies) nor
**     the names of its contributors may be used to endorse or promote
**     products derived from this software without specific prior written
**     permission.
**
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
** "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
** LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
** A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
** OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
** SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
** LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
** DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
** THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
** OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
** $QT_END_LICENSE$
**
****************************************************************************/

// FastScroll.qml
import QtQuick 2.2
import Ubuntu.Components 1.1
import "FastScroll.js" as Sections

Item {
    id: root

    property ListView listView
    property int pinSize: units.gu(2)

    readonly property var letters: ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "#"]
    readonly property alias fastScrolling: internal.fastScrolling
    readonly property bool showing: (rail.opacity !== 0.0)

    width: units.gu(7)
    onListViewChanged: {
        if (listView && listView.model) {
            internal.initDirtyObserver();
        } else if (listView) {
            listView.modelChanged.connect(function() {
                if (listView.model) {
                    internal.initDirtyObserver();
                }
            });
        }
    }

    Rectangle {
        id: magnified

        color: Theme.palette.normal.overlay
        radius: height * 0.3
        height: pinSize * 2
        width: height
        opacity: internal.fastScrolling ? 1.0 : 0.0
        x: -cursor.width - units.gu(3)
        y: {
            if (internal.currentItem) {
                var itemCenterY = rail.y + internal.currentItem.y + (internal.currentItem.height / 2)
                return (itemCenterY - (magnified.height / 2))
            } else {
                return 0
            }
        }

        Label {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: internal.desireSection
            fontSize: "small"
        }

        Behavior on opacity {
            UbuntuNumberAnimation {}
        }
    }


    Rectangle {
        id: cursor

        property bool showLabel: false
        property string currentSectionName: ""

        radius: pinSize * 0.3
        height: pinSize
        width: height
        color: Theme.palette.normal.foreground
        opacity: rail.opacity
        x: rail.x
        y: {
            if (internal.currentItem) {
                var itemCenterY = rail.y + internal.currentItem.y + (internal.currentItem.height / 2)
                return (itemCenterY - (cursor.height / 2))
            } else {
                return 0
            }
        }
        Behavior on y {
            enabled: !internal.fastScrolling
            UbuntuNumberAnimation { }
        }
    }

    Column {
        id: rail

        property bool isVisible: root.enabled && (listView.moving || dragArea.pressed)

        anchors {
            right: parent.right
            rightMargin: units.gu(2)
            left: parent.left
            leftMargin: units.gu(2)
            top: parent.top
        }
        height: childrenRect.height
        opacity: 0.0
        onIsVisibleChanged: {
            if (isVisible) {
                rail.opacity = 1.0
                hideTimer.stop()
            } else {
                hideTimer.restart()
            }
        }

        Behavior on opacity {
            UbuntuNumberAnimation { }
        }

        Repeater {
            id: sectionsRepeater

            model: root.letters
            Label {
                id: lbl

                anchors.left: parent.left
                height: pinSize
                width: pinSize
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: internal.fastScrolling && internal.targetSection == modelData ? "" : modelData
                fontSize: "x-small"
                color: internal.currentItem.text === text ? Theme.palette.selected.foregroundText : Theme.palette.selected.backgroundText
                opacity: !internal.modelDirty && Sections.contains(text) ? 1.0 : 0.5
            }
        }

        Timer {
            id: hideTimer

            running: false
            interval: 2000
            onTriggered: rail.opacity = 0.0
        }
    }

    MouseArea {
        id: dragArea

        anchors {
            left: parent.left
            right: parent.right
        }
        y: rail.y
        height: rail.height
        visible: rail.opacity == 1.0

        preventStealing: true
        onPressed: {
            internal.adjustContentPosition(mouseY)
            dragginTimer.start()
        }

        onReleased: {
            dragginTimer.stop()
            internal.desireSection = ""
            internal.fastScrolling = false
        }

        onPositionChanged: internal.adjustContentPosition(mouseY)

        Timer {
            id: dragginTimer

            running: false
            interval: 150
            onTriggered: {
                internal.fastScrolling = true
            }
        }
    }

    Timer {
        id: dirtyTimer
        interval: 500
        running: false
        onTriggered: {
            Sections.initSectionData(listView);
            internal.modelDirty = false;
        }
    }

    Timer {
        id: timerScroll

        running: false
        interval: 10
        onTriggered: {
            if (internal.desireSection != internal.currentSection) {
                var idx = Sections.getIndexFor(internal.desireSection)
                if (idx !== -1) {
                    listView.positionViewAtIndex(idx, ListView.Beginning)
                }
            }
        }
    }

    QtObject {
        id: internal

        property string currentSection: listView.currentSection
        property string desireSection: ""
        property string targetSection: fastScrolling ? desireSection : currentSection
        property int oldY: 0
        property bool modelDirty: false
        property bool down: true
        property bool fastScrolling: false
        property var currentItem: null

        onTargetSectionChanged: moveIndicator(targetSection)

        function initDirtyObserver() {
            Sections.initialize(listView);
            function dirtyObserver() {
                if (!internal.modelDirty) {
                    internal.modelDirty = true;
                    dirtyTimer.running = true;
                }
            }

            if (listView.model.countChanged)
                listView.model.countChanged.connect(dirtyObserver);

            if (listView.model.itemsChanged)
                listView.model.itemsChanged.connect(dirtyObserver);

            if (listView.model.itemsInserted)
                listView.model.itemsInserted.connect(dirtyObserver);

            if (listView.model.itemsMoved)
                listView.model.itemsMoved.connect(dirtyObserver);

            if (listView.model.itemsRemoved)
                listView.model.itemsRemoved.connect(dirtyObserver);
        }

        function adjustContentPosition(mouseY) {
            var child = rail.childAt(rail.width / 2, mouseY)
            if (!child || child.text === "") {
                return
            }
            var section = child.text
            if (internal.desireSection !== section) {
                internal.desireSection = section
                moveIndicator(section)
                timerScroll.restart()
            }
        }

        function moveIndicator(section)
        {
            var index = root.letters.indexOf(section)
            if (index != -1) {
                currentItem = sectionsRepeater.itemAt(index)
            }
        }
    }
}