#include "script_component.hpp"
/*
    FUNC(serverSetup)

    Description:
        Server-side performance broadcaster. Every 20 seconds the current
        server FPS (via diag_fps) is sent to all connected machines through
        a global "serverFPS" event so that clients can display or react to
        degraded server performance.

    Called once on the server during module init.
*/

if (!isServer) exitWith {};

[{
    private _currentFPS = diag_fps;

    ["serverFPS", [_currentFPS]] call PRA3_fw_fireGlobal;

    diag_log format ["[PRA3 PerformanceInfo] Server FPS broadcast: %1", round _currentFPS];

}, 20] call PRA3_fw_addPFH;

diag_log "[PRA3 PerformanceInfo] Server FPS broadcaster started (20s interval).";
