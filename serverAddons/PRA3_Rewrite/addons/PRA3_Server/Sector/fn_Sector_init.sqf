#include "script_component.hpp"
/*
    FUNC(init)

    Description:
        Shared initialisation for the Sector module. Runs on every machine.
        Blocks until EGVAR(Common,competingSides) is populated, wires up
        client-side drawing hooks, then waits for the server to signal
        GVAR(setupDone) before allowing client interaction.

    Called via CfgFunctions preInit.
*/

// ======================================================================
// 1. Wait for competing sides to be resolved by the Common module
// ======================================================================
[{
    private _sides = missionNamespace getVariable [QEGVAR(Common,competingSides), []];
    !(_sides isEqualTo [])
}, {

    // ------------------------------------------------------------------
    // 2. Client: register drawing hooks for side and ownership changes
    // ------------------------------------------------------------------
    if (hasInterface) then {
        ["sideChanged", {
            {
                [_x] call FUNC(draw);
            } forEach GVAR(sectorList);
        }] call PRA3_fw_addHandler;

        ["sectorOwnerChanged", {
            {
                [_x] call FUNC(draw);
            } forEach GVAR(sectorList);
        }] call PRA3_fw_addHandler;
    };

    // ------------------------------------------------------------------
    // 3. Server-side setup
    // ------------------------------------------------------------------
    if (isServer) then {
        [] call FUNC(serverSetup);
    };

    // ------------------------------------------------------------------
    // 4. Wait for server to broadcast GVAR(setupDone)
    // ------------------------------------------------------------------
    [{
        missionNamespace getVariable [QGVAR(setupDone), false]
    }, {
        // Client interaction setup
        if (hasInterface) then {
            [] call FUNC(clientSetup);
        };

        // Initial draw pass for every sector
        if (hasInterface) then {
            {
                [_x] call FUNC(draw);
            } forEach GVAR(sectorList);
        };

        diag_log "[PRA3 Sector] Init complete on this machine.";
    }] call PRA3_fw_waitUntilExec;

}] call PRA3_fw_waitUntilExec;

diag_log "[PRA3 Sector] Init started, waiting for competing sides.";
