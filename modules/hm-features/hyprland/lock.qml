pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland

ShellRoot {
    id: root

    // WARNING: full-screen rapid flashing can trigger photosensitive seizures.
    readonly property var failureColors: ["#ff0000", "#ff8000", "#ffff00", "#80ff00", "#00ff00", "#00ff80", "#00ffff", "#0080ff", "#0000ff", "#8000ff", "#ff00ff", "#ff0080"]
    property real failureAngle: 0
    readonly property bool failing: failureAnimation.running
    readonly property color backgroundColor: failing ? failureColors[Math.floor(failureAngle / 30) % failureColors.length] : "#000000"
    property string response: ""
    property string pendingPassword: ""
    property bool hasPendingPassword: false
    property string status: "Enter your password"
    readonly property bool acceptingInput: lock.secure && !failing && (!pam.active || pam.responseRequired)

    function submit() {
        if (!acceptingInput)
            return;
        if (pam.active) {
            const answer = response;
            response = "";
            pam.respond(answer);
        } else {
            pendingPassword = response;
            hasPendingPassword = true;
            response = "";
            status = "Authenticating…";
            if (!pam.start()) {
                pendingPassword = "";
                hasPendingPassword = false;
                status = "Unable to start authentication";
            }
        }
    }

    PamContext {
        id: pam
        config: "quickshell-lock"

        onPamMessage: {
            if (responseRequired && root.hasPendingPassword && !responseVisible) {
                const answer = root.pendingPassword;
                root.pendingPassword = "";
                root.hasPendingPassword = false;
                respond(answer);
            } else {
                root.pendingPassword = "";
                root.hasPendingPassword = false;
                root.status = message;
            }
        }
        onCompleted: result => {
            root.response = "";
            root.pendingPassword = "";
            root.hasPendingPassword = false;
            if (result === PamResult.Success) {
                // This is the only path that releases the compositor lock.
                lock.locked = false;
                Qt.callLater(() => Qt.quit());
            } else if (result === PamResult.Failed || result === PamResult.MaxTries) {
                root.status = "Authentication failed";
                failureAnimation.restart();
            } else {
                root.status = "Authentication error — try again";
            }
        }
    }

    SequentialAnimation {
        id: failureAnimation
        NumberAnimation {
            target: root
            property: "failureAngle"
            from: 0
            to: 1080
            duration: 3000
            easing.type: Easing.Linear
        }
        PropertyAction {
            target: root
            property: "failureAngle"
            value: 0
        }
        onFinished: root.status = "Enter your password"
    }

    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            id: surface
            color: root.backgroundColor

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(300, surface.width - 40)
                height: 50
                radius: 8
                color: "#222222"
                border.color: root.failing ? "#ffffff" : "#777777"
                rotation: root.failureAngle

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.margins: 12
                    color: "#ffffff"
                    font.pixelSize: 20
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    echoMode: pam.active && pam.responseVisible ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "●"
                    text: root.response
                    enabled: root.acceptingInput
                    focus: true
                    selectByMouse: false
                    activeFocusOnPress: true
                    onTextEdited: root.response = text
                    onAccepted: root.submit()
                    onEnabledChanged: {
                        if (enabled)
                            forceActiveFocus();
                    }
                    Component.onCompleted: forceActiveFocus()
                    Keys.onEscapePressed: root.response = ""
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 + 190
                width: Math.max(0, parent.width - 40)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: root.status
                color: "#ffffff"
                font.pixelSize: 18
            }
        }
    }
}
