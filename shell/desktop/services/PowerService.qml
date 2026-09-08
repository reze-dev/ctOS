pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    // =========================================================================
    // Public Interface Contract
    // =========================================================================

    // True if UPower service daemon is responsive and ready
    readonly property bool available: UPower !== null && UPower.displayDevice !== null && UPower.displayDevice.ready

    // Desktop Omission Contract:
    // When running on a desktop system without a physical battery (isPresent === false),
    // isBatteryPresent evaluates strictly to false, enabling clean omission of the battery indicator.
    // Battery widget visible binding: isBatteryPresent && available
    readonly property bool isBatteryPresent: root.available && Boolean(UPower.displayDevice && UPower.displayDevice.isPresent)

    // True strictly when battery is actively receiving charge
    readonly property bool isCharging: {
        if (!root.isBatteryPresent || !UPower.displayDevice) {
            return false;
        }
        const state = UPower.displayDevice.state;
        return state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge;
    }

    // True when battery is 100% full or reports FullyCharged state
    readonly property bool isFull: {
        if (!root.isBatteryPresent || !UPower.displayDevice) {
            return false;
        }
        return UPower.displayDevice.state === UPowerDeviceState.FullyCharged || root.percentage >= 99.5;
    }

    // True when operating on battery power rather than AC mains
    readonly property bool onBattery: root.available && UPower.onBattery

    // Normalized battery percentage strictly bounded [0.0, 100.0]
    // Safely handles both normalized [0.0, 1.0] and raw [0, 100] inputs without division by zero.
    readonly property real percentage: {
        if (!root.isBatteryPresent || !UPower.displayDevice) {
            return 0.0;
        }
        const raw = UPower.displayDevice.percentage;
        // Quickshell UPower device normalizes percentage to [0.0, 1.0]
        const scaled = (raw <= 1.0) ? (raw * 100.0) : raw;
        return Math.min(100.0, Math.max(0.0, scaled));
    }

    // Human-readable power state text
    readonly property string stateText: {
        if (!root.available || !root.isBatteryPresent || !UPower.displayDevice) {
            return "--N/A--";
        }
        switch (UPower.displayDevice.state) {
        case UPowerDeviceState.Charging:
            return "Charging";
        case UPowerDeviceState.Discharging:
            return "Discharging";
        case UPowerDeviceState.FullyCharged:
            return "Full";
        case UPowerDeviceState.Empty:
            return "Empty";
        case UPowerDeviceState.PendingCharge:
            return "Pending Charge";
        case UPowerDeviceState.PendingDischarge:
            return "Pending Discharge";
        case UPowerDeviceState.Unknown:
        default:
            return "Unknown";
        }
    }

    // Estimated seconds remaining until battery is fully depleted (or 0 if on AC)
    readonly property real timeToEmpty: (isBatteryPresent && UPower.displayDevice) ? UPower.displayDevice.timeToEmpty : 0.0

    // Estimated seconds remaining until battery reaches 100% (or 0 if discharging)
    readonly property real timeToFull: (isBatteryPresent && UPower.displayDevice) ? UPower.displayDevice.timeToFull : 0.0

    // Signals
    signal powerStateChanged(real percentage, bool isCharging, string stateText)

    // Notify listeners when relevant power properties change
    onPercentageChanged: root.powerStateChanged(root.percentage, root.isCharging, root.stateText)
    onIsChargingChanged: root.powerStateChanged(root.percentage, root.isCharging, root.stateText)
    onStateTextChanged: root.powerStateChanged(root.percentage, root.isCharging, root.stateText)
}
