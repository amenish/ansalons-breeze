/*
    SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import Qt5Compat.GraphicalEffects

import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.kirigami 2.20 as Kirigami

import org.kde.breeze.components

Item {
    id: root

    // If we're using software rendering, draw outlines instead of shadows
    // See https://bugs.kde.org/show_bug.cgi?id=398317
    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
    Kirigami.Theme.inherit: false

    width: 1600
    height: 900

    property string notificationMessage

    // Opciones numéricas de theme.conf (llegan como texto)
    function opcionNumerica(valor, porDefecto) {
        const n = parseFloat(valor);
        return isNaN(n) ? porDefecto : n;
    }

    readonly property int duracionEntrada: Math.max(0, opcionNumerica(config.entryDuration, 1200))
    // Desplazamientos verticales, en % del alto de pantalla (positivo = más abajo)
    readonly property real desplazamientoReloj: height * opcionNumerica(config.clockOffset, 0) / 100
    readonly property real desplazamientoLogin: height * opcionNumerica(config.loginOffset, 0) / 100

    // Fondo según la hora: amanecer, día, atardecer y noche
    property int hora: new Date().getHours()
    readonly property url fondoActual: {
        if (config.timeBackground !== "true" || config.type !== "image") {
            return config.background;
        }
        const amanecer = opcionNumerica(config.dawnHour, 6);
        const dia = opcionNumerica(config.dayHour, 9);
        const atardecer = opcionNumerica(config.duskHour, 18);
        const noche = opcionNumerica(config.nightHour, 21);
        let imagen;
        if (hora >= amanecer && hora < dia) {
            imagen = config.backgroundDawn;
        } else if (hora >= dia && hora < atardecer) {
            imagen = config.backgroundDay;
        } else if (hora >= atardecer && hora < noche) {
            imagen = config.backgroundDusk;
        } else {
            imagen = config.backgroundNight;
        }
        return imagen ? Qt.resolvedUrl(imagen) : config.background;
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.hora = new Date().getHours()
    }

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    Item {
        id: wallpaper
        anchors.fill: parent
        Repeater {
            model: screenModel

            Background {
                x: geometry.x; y: geometry.y; width: geometry.width; height: geometry.height
                sceneBackgroundType: config.type
                sceneBackgroundColor: config.color
                sceneBackgroundImage: root.fondoActual
            }
        }
    }

    RejectPasswordAnimation {
        id: rejectPasswordAnimation
        target: mainStack
    }

    MouseArea {
        id: loginScreenRoot
        anchors.fill: parent

        property bool uiVisible: true
        property bool blockUI: mainStack.depth > 1 || userListComponent.mainPasswordBox.text.length > 0 || config.type !== "image"

        // Entrada gradual: la interfaz arranca transparente y aparece tras el primer fotograma
        property bool arrancado: false
        property bool entradaEnCurso: true

        // El fondo se ve nítido y solo se desenfoca al elegir avatar o al teclear
        property bool avatarElegido: false
        readonly property bool desenfocar: config.blurOnInteraction !== "false" && config.type === "image"
            && arrancado && uiVisible
            && (avatarElegido || mainStack.depth > 1 || userListComponent.mainPasswordBox.text.length > 0)
        property real factorDesenfoque: desenfocar ? 1 : 0
        Behavior on factorDesenfoque {
            NumberAnimation {
                duration: 600
                easing.type: Easing.InOutQuad
            }
        }

        Timer {
            interval: 100
            running: true
            onTriggered: loginScreenRoot.arrancado = true
        }

        hoverEnabled: true
        // Sin esto el greeter no fija cursor y en X11 no se ve el puntero
        cursorShape: Qt.ArrowCursor
        drag.filterChildren: true
        onPressed: uiVisible = true;
        onPositionChanged: uiVisible = true;
        onUiVisibleChanged: {
            if (!uiVisible) {
                avatarElegido = false;
            }
            if (blockUI) {
                fadeoutTimer.running = false;
            } else if (uiVisible) {
                fadeoutTimer.restart();
            }
        }
        onBlockUIChanged: {
            if (blockUI) {
                fadeoutTimer.running = false;
                uiVisible = true;
            } else {
                fadeoutTimer.restart();
            }
        }

        Keys.onPressed: event => {
            uiVisible = true;
            event.accepted = false;
        }

        //takes one full minute for the ui to disappear
        Timer {
            id: fadeoutTimer
            running: true
            interval: 60000
            onTriggered: {
                if (!loginScreenRoot.blockUI) {
                    userListComponent.mainPasswordBox.showPassword = false;
                    loginScreenRoot.uiVisible = false;
                }
            }
        }
        FastBlur {
            anchors.fill: parent
            source: wallpaper
            radius: 50 * loginScreenRoot.factorDesenfoque
            visible: !softwareRendering && loginScreenRoot.factorDesenfoque > 0
        }

        // Oscurece el fondo desenfocado para dar contraste al formulario
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.3 * loginScreenRoot.factorDesenfoque
            visible: opacity > 0
        }

        DropShadow {
            id: clockShadow
            anchors.fill: clock
            source: clock
            visible: !softwareRendering && config.showClock === "true"
            radius: 7
            verticalOffset: 0.8
            samples: 15
            spread: 0.2
            color : Qt.rgba(0, 0, 0, 0.7)
            // Sombra solo mientras el fondo está nítido, para que el reloj se lea
            opacity: clock.opacity * (1 - loginScreenRoot.factorDesenfoque)
        }

        Clock {
            id: clock
            property Item shadow: clockShadow
            visible: y > 0 && config.showClock === "true"
            anchors.horizontalCenter: parent.horizontalCenter
            y: userListComponent.userList.y / 2 - height / 2 + root.desplazamientoReloj
            opacity: 0
            Layout.alignment: Qt.AlignBaseline
        }

        QQC2.StackView {
            id: mainStack
            anchors {
                left: parent.left
                right: parent.right
            }
            y: root.desplazamientoLogin
            height: root.height + Kirigami.Units.gridUnit * 3
            opacity: 0

            // If true (depends on the style and environment variables), hover events are always accepted
            // and propagation stopped. This means the parent MouseArea won't get them and the UI won't be shown.
            // Disable capturing those events while the UI is hidden to avoid that, while still passing events otherwise.
            // One issue is that while the UI is visible, mouse activity won't keep resetting the timer, but when it
            // finally expires, the next event should immediately set uiVisible = true again.
            hoverEnabled: loginScreenRoot.uiVisible ? undefined : false

            focus: true //StackView is an implicit focus scope, so we need to give this focus so the item inside will have it

            Timer {
                //SDDM has a bug in 0.13 where even though we set the focus on the right item within the window, the window doesn't have focus
                //it is fixed in 6d5b36b28907b16280ff78995fef764bb0c573db which will be 0.14
                //we need to call "window->activate()" *After* it's been shown. We can't control that in QML so we use a shoddy timer
                //it's been this way for all Plasma 5.x without a huge problem
                running: true
                repeat: false
                interval: 200
                onTriggered: mainStack.forceActiveFocus()
            }

            initialItem: Login {
                id: userListComponent
                userListModel: userModel
                loginScreenUiVisible: loginScreenRoot.uiVisible
                userListCurrentIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
                lastUserName: userModel.lastUser
                showUserList: {
                    if (!userListModel.hasOwnProperty("count")
                        || !userListModel.hasOwnProperty("disableAvatarsThreshold")) {
                        return false
                    }

                    if (userListModel.count === 0 ) {
                        return false
                    }

                    if (userListModel.hasOwnProperty("containsAllUsers") && !userListModel.containsAllUsers) {
                        return false
                    }

                    return userListModel.count <= userListModel.disableAvatarsThreshold
                }

                notificationMessage: {
                    const parts = [];
                    if (capsLockState.locked) {
                        parts.push(i18nd("plasma-desktop-sddm-theme", "Caps Lock is on"));
                    }
                    if (root.notificationMessage) {
                        parts.push(root.notificationMessage);
                    }
                    return parts.join(" • ");
                }

                // Los botones de acción van en botonesAccion, al pie de la pantalla.
                // El componente de Breeze necesita al menos un elemento en la lista.
                actionItemsVisible: false
                actionItems: [ Item {} ]

                onUserSelected: loginScreenRoot.avatarElegido = true

                onLoginRequest: {
                    root.notificationMessage = ""
                    sddm.login(username, password, sessionButton.currentIndex)
                }
            }

            Behavior on opacity {
                enabled: !loginScreenRoot.entradaEnCurso
                OpacityAnimator {
                    duration: Kirigami.Units.longDuration
                }
            }

            readonly property real zoomFactor: 1.5

            popEnter: Transition {
                ScaleAnimator {
                    from: mainStack.zoomFactor
                    to: 1
                    duration: Kirigami.Units.veryLongDuration
                    easing.type: Easing.OutCubic
                }
                OpacityAnimator {
                    from: 0
                    to: 1
                    duration: Kirigami.Units.veryLongDuration
                    easing.type: Easing.OutCubic
                }
            }

            popExit: Transition {
                ScaleAnimator {
                    from: 1
                    to: 1 / mainStack.zoomFactor
                    duration: Kirigami.Units.veryLongDuration
                    easing.type: Easing.OutCubic
                }
                OpacityAnimator {
                    from: 1
                    to: 0
                    duration: Kirigami.Units.veryLongDuration
                    easing.type: Easing.OutCubic
                }
            }

            pushEnter: Transition {
                ScaleAnimator {
                    from: 1 / mainStack.zoomFactor
                    to: 1
                    duration: Kirigami.Units.veryLongDuration
                    easing.type: Easing.OutCubic
                }
                OpacityAnimator {
                    from: 0
                    to: 1
                    duration: Kirigami.Units.veryLongDuration
                    easing.type: Easing.OutCubic
                }
            }

            pushExit: Transition {
                ScaleAnimator {
                    from: 1
                    to: mainStack.zoomFactor
                    duration: Kirigami.Units.veryLongDuration
                    easing.type: Easing.OutCubic
                }
                OpacityAnimator {
                    from: 1
                    to: 0
                    duration: Kirigami.Units.veryLongDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        Component {
            id: userPromptComponent
            Login {
                showUsernamePrompt: true
                notificationMessage: root.notificationMessage
                loginScreenUiVisible: loginScreenRoot.uiVisible
                fontSize: Kirigami.Theme.defaultFont.pointSize + 2

                // using a model rather than a QObject list to avoid QTBUG-75900
                userListModel: ListModel {
                    ListElement {
                        name: ""
                        icon: ""
                    }
                    Component.onCompleted: {
                        // as we can't bind inside ListElement
                        setProperty(0, "name", i18nd("plasma-desktop-sddm-theme", "Type in Username and Password"));
                        setProperty(0, "icon", Qt.resolvedUrl("faces/.face.icon"))
                    }
                }

                onLoginRequest: {
                    root.notificationMessage = ""
                    sddm.login(username, password, sessionButton.currentIndex)
                }

                actionItemsVisible: false
                actionItems: [ Item {} ]
            }
        }

        DropShadow {
            id: logoShadow
            anchors.fill: logo
            source: logo
            visible: !softwareRendering && config.showlogo === "shown"
            horizontalOffset: 1
            verticalOffset: 1
            radius: 6
            samples: 14
            spread: 0.3
            color : "black" // shadows should always be black
            opacity: loginScreenRoot.uiVisible ? 0 : 1
            Behavior on opacity {
                //OpacityAnimator when starting from 0 is buggy (it shows one frame with opacity 1)"
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.InOutQuad
                }
            }
        }

        Image {
            id: logo
            visible: config.showlogo === "shown"
            source: config.logo
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: footer.top
            anchors.bottomMargin: Kirigami.Units.largeSpacing
            asynchronous: true
            sourceSize.height: height
            opacity: loginScreenRoot.uiVisible ? 0 : 1
            fillMode: Image.PreserveAspectFit
            height: Math.round(Kirigami.Units.gridUnit * 3.5)
            Behavior on opacity {
                // OpacityAnimator when starting from 0 is buggy (it shows one frame with opacity 1)"
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.InOutQuad
                }
            }
        }

        // Note: Containment masks stretch clickable area of their buttons to
        // the screen edges, essentially making them adhere to Fitts's law.
        // Due to virtual keyboard button having an icon, buttons may have
        // different heights, so fillHeight is required.
        //
        // Note for contributors: Keep this in sync with LockScreenUi.qml footer.
        RowLayout {
            id: footer
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                margins: Kirigami.Units.smallSpacing
            }
            spacing: Kirigami.Units.smallSpacing
            opacity: 0

            Behavior on opacity {
                enabled: !loginScreenRoot.entradaEnCurso
                OpacityAnimator {
                    duration: Kirigami.Units.longDuration
                }
            }

            KeyboardButton {
                id: keyboardButton

                onKeyboardLayoutChanged: {
                    // Otherwise the password field loses focus and virtual keyboard
                    // keystrokes get eaten
                    userListComponent.mainPasswordBox.forceActiveFocus();
                }

                Layout.fillHeight: true
                containmentMask: Item {
                    parent: keyboardButton
                    anchors.fill: parent
                    anchors.leftMargin: -footer.anchors.margins
                    anchors.bottomMargin: -footer.anchors.margins
                }
            }

            SessionButton {
                id: sessionButton

                onSessionChanged: {
                    // Otherwise the password field loses focus and virtual keyboard
                    // keystrokes get eaten
                    userListComponent.mainPasswordBox.forceActiveFocus();
                }

                Layout.fillHeight: true
                containmentMask: Item {
                    parent: sessionButton
                    anchors.fill: parent
                    anchors.leftMargin: keyboardButton.visible ? 0 : -footer.anchors.margins
                    anchors.bottomMargin: -footer.anchors.margins
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Battery {}
        }

        // Botones de energía y cambio de modo, centrados en el borde inferior
        Row {
            id: botonesAccion
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Kirigami.Units.gridUnit
            }
            spacing: Kirigami.Units.largeSpacing
            opacity: footer.opacity
            enabled: footer.enabled

            PowerButton { powerAction: "suspend" }
            PowerButton { powerAction: "reboot" }
            PowerButton { powerAction: "poweroff" }
            ActionButton {
                readonly property bool enLista: mainStack.depth <= 1
                icon.name: enLista ? "system-user-prompt" : "system-user-list"
                text: enLista
                    ? i18ndc("plasma-desktop-sddm-theme", "For switching to a username and password prompt", "Other…")
                    : i18nd("plasma-desktop-sddm-theme", "List Users")
                visible: !enLista || !userListComponent.showUsernamePrompt
                onClicked: enLista ? mainStack.push(userPromptComponent) : mainStack.pop()
            }
        }

        // Visibilidad de reloj, formulario y pie. Solo cambia la opacidad:
        // "inicio" es el arranque (todo transparente), "off" la interfaz
        // oculta por inactividad.
        state: !arrancado ? "inicio" : (uiVisible ? "on" : "off")
        states: [
            State {
                name: "inicio"
            },
            State {
                name: "on"
                PropertyChanges { target: clock; opacity: 1 }
                PropertyChanges { target: mainStack; opacity: 1 }
                PropertyChanges { target: footer; opacity: 1 }
            },
            State {
                name: "off"
                PropertyChanges { target: clock; opacity: 0 }
                PropertyChanges { target: mainStack; opacity: 0 }
                PropertyChanges { target: footer; opacity: 0 }
            }
        ]
        transitions: [
            Transition {
                from: "inicio"
                to: "on"
                onRunningChanged: {
                    if (!running) {
                        loginScreenRoot.entradaEnCurso = false;
                    }
                }
                // Primero el reloj, después formulario y pie
                SequentialAnimation {
                    NumberAnimation {
                        target: clock
                        property: "opacity"
                        duration: root.duracionEntrada
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        targets: [mainStack, footer]
                        property: "opacity"
                        duration: root.duracionEntrada
                        easing.type: Easing.InOutQuad
                    }
                }
            },
            Transition {
                from: "on"
                to: "off"
                NumberAnimation {
                    targets: [mainStack, footer, clock]
                    property: "opacity"
                    duration: Kirigami.Units.veryLongDuration
                    easing.type: Easing.InOutQuad
                }
            },
            Transition {
                from: "off"
                to: "on"
                NumberAnimation {
                    targets: [mainStack, footer, clock]
                    property: "opacity"
                    duration: Kirigami.Units.veryLongDuration
                    easing.type: Easing.InOutQuad
                }
            }
        ]
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            notificationMessage = i18nd("plasma-desktop-sddm-theme", "Login Failed")
            footer.enabled = true
            mainStack.enabled = true
            userListComponent.userList.opacity = 1
            rejectPasswordAnimation.start()
        }
        function onLoginSucceeded() {
            //note SDDM will kill the greeter at some random point after this
            //there is no certainty any transition will finish, it depends on the time it
            //takes to complete the init
            mainStack.opacity = 0
            footer.opacity = 0
        }
    }

    onNotificationMessageChanged: {
        if (notificationMessage) {
            notificationResetTimer.start();
        }
    }

    Timer {
        id: notificationResetTimer
        interval: 3000
        onTriggered: notificationMessage = ""
    }
}
