#include "script_component.hpp"
/*
    FUNC(serverSetup)

    Description:
        Server-only rally-point watchdog. Tracks all active rally deploy
        points and sweeps them every 0.2 seconds. Rallies whose owning
        group no longer exists are removed. Rallies with enemies within
        the detection radius (default 10 m, 1 enemy) are destroyed.

    Execution: server only, called once during module init.
*/

if (!isServer) exitWith {};

// ======================================================================
// 1. Tracking array and config
// ======================================================================
GVAR(liveRallies) = [];

private _cfg = missionConfigFile >> "PRA3" >> "RallyConfig";

GVAR(enemyScanRange) = getNumber (_cfg >> "enemyScanRange");
GVAR(enemyScanLimit) = getNumber (_cfg >> "enemyScanLimit");

if (GVAR(enemyScanRange) <= 0) then { GVAR(enemyScanRange) = 10; };
if (GVAR(enemyScanLimit) <= 0) then { GVAR(enemyScanLimit) = 1;  };

// ======================================================================
// 2. Validation PFH — runs every 0.2 s
// ======================================================================
[{
    params ["_args", "_handle"];

    private _condemned = [];

    {
        private _rId = _x;
        private _rec = EGVAR(Deployment,pointStorage) getOrDefault [_rId, createHashMap];

        // Already gone from the registry
        if (count _rec == 0) then {
            _condemned pushBack [_rId, "removed"];
            continue;
        };

        private _rPos   = _rec getOrDefault ["position", [0, 0, 0]];
        private _owner  = _rec getOrDefault ["availableFor", grpNull];

        // --- Group existence check ---
        if (_owner isEqualType grpNull) then {
            if (isNull _owner || {count units _owner == 0}) then {
                _condemned pushBack [_rId, "disbanded"];
                continue;
            };
        };

        // --- Enemy proximity check ---
        private _ownerSide = if (_owner isEqualType grpNull) then {
            side _owner
        } else {
            _owner
        };

        private _nearbyUnits = [_rPos, GVAR(enemyScanRange)] call PRA3_fw_getNearUnits;
        private _hostiles    = 0;

        {
            if !(side group _x isEqualTo _ownerSide) then {
                _hostiles = _hostiles + 1;
            };
        } forEach _nearbyUnits;

        if (_hostiles >= GVAR(enemyScanLimit)) then {
            _condemned pushBack [_rId, "enemy"];
        };
    } forEach +GVAR(liveRallies);

    // Destroy flagged rallies
    {
        _x params ["_rId", "_why"];
        [_rId, _why] call FUNC(destroy);
    } forEach _condemned;

}, 0.2, []] call PRA3_fw_addPFH;

diag_log "[PRA3:Rally] Server setup finished.";
