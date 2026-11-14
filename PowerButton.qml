import QtQuick 2.15

import org.kde.breeze.components

// Botón de energía común a las dos pantallas de login.
// powerAction: "suspend" | "reboot" | "poweroff"
ActionButton {
    property string powerAction

    icon.name: ({ suspend: "system-suspend", reboot: "system-reboot", poweroff: "system-shutdown" })[powerAction]
    text: powerAction === "suspend" ? i18ndc("plasma-desktop-sddm-theme", "Suspend to RAM", "Sleep")
        : powerAction === "reboot" ? i18nd("plasma-desktop-sddm-theme", "Restart")
        : i18nd("plasma-desktop-sddm-theme", "Shut Down")
    enabled: powerAction === "suspend" ? sddm.canSuspend
        : powerAction === "reboot" ? sddm.canReboot
        : sddm.canPowerOff
    onClicked: {
        if (powerAction === "suspend") sddm.suspend();
        else if (powerAction === "reboot") sddm.reboot();
        else sddm.powerOff();
    }
}
