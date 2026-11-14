/*
    SPDX-FileCopyrightText: 2016 Boudhayan Gupta <bgupta@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick 2.15

FocusScope {
    id: sceneBackground

    property var sceneBackgroundType
    property alias sceneBackgroundColor: sceneColorBackground.color
    property url sceneBackgroundImage

    // Fundido cruzado: la imagen nueva se carga en la capa oculta, encima de
    // la visible, y aparece gradualmente cuando ya está lista.
    property Image capaVisible: capaA
    readonly property Image capaOculta: capaVisible === capaA ? capaB : capaA
    property string fondoCargado: ""

    onSceneBackgroundImageChanged: cargarFondo()
    Component.onCompleted: cargarFondo()

    function cargarFondo() {
        const nuevo = sceneBackgroundImage.toString();
        if (nuevo === fondoCargado) {
            return;
        }
        if (fundido.running) {
            fundido.stop();
            terminarFundido();
        }
        const primeraCarga = fondoCargado === "";
        fondoCargado = nuevo;
        if (primeraCarga) {
            capaVisible.source = sceneBackgroundImage;
            return;
        }
        capaOculta.opacity = 0;
        capaOculta.z = 1;
        capaVisible.z = 0;
        capaOculta.source = sceneBackgroundImage;
        iniciarFundidoSiLista();
    }

    function iniciarFundidoSiLista() {
        if (capaOculta.status === Image.Ready && capaOculta.opacity === 0 && !fundido.running) {
            fundido.start();
        }
    }

    function terminarFundido() {
        const vieja = capaVisible;
        const nueva = capaOculta;
        nueva.opacity = 1;
        capaVisible = nueva;
        vieja.opacity = 0;
        vieja.source = "";
    }

    Rectangle {
        id: sceneColorBackground
        anchors.fill: parent
    }

    Item {
        id: sceneImageBackground
        anchors.fill: parent

        Image {
            id: capaA
            anchors.fill: parent
            sourceSize.width: parent.width
            sourceSize.height: parent.height
            fillMode: Image.PreserveAspectCrop
            smooth: true
            onStatusChanged: if (sceneBackground.capaOculta === capaA) sceneBackground.iniciarFundidoSiLista()
        }

        Image {
            id: capaB
            anchors.fill: parent
            sourceSize.width: parent.width
            sourceSize.height: parent.height
            fillMode: Image.PreserveAspectCrop
            smooth: true
            opacity: 0
            onStatusChanged: if (sceneBackground.capaOculta === capaB) sceneBackground.iniciarFundidoSiLista()
        }

        NumberAnimation {
            id: fundido
            target: sceneBackground.capaOculta
            property: "opacity"
            from: 0
            to: 1
            duration: 2000
            easing.type: Easing.InOutQuad
            onFinished: sceneBackground.terminarFundido()
        }
    }

    states: [
        State {
            name: "imageBackground"
            when: sceneBackgroundType === "image"
            PropertyChanges {
                target: sceneColorBackground
                visible: false
            }
            PropertyChanges {
                target: sceneImageBackground
                visible: true
            }
        },
        State {
            name: "colorBackground"
            when: sceneBackgroundType !== "image"
            PropertyChanges {
                target: sceneColorBackground
                visible: true
            }
            PropertyChanges {
                target: sceneImageBackground
                visible: false
            }
        }
    ]
}
