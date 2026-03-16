#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-side bootstrap for the notification sub-system.
        Initialises the priority queue used to hold pending notifications
        and wires up the "showNotification" event so that incoming
        messages are forwarded to FUNC(show) for display.

    Called once per client during module init.
*/

if (!hasInterface) exitWith {};

// Priority-sorted list of pending notification entries
GVAR(queue) = [];

// Semaphore that prevents overlapping display animations
GVAR(processing) = false;

// Wire the network event to the local display logic
["showNotification", {
    _this call FUNC(show);
}] call PRA3_fw_addHandler;

diag_log "[PRA3 Notification] Client subsystem ready.";
