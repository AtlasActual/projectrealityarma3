#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-side rally-point initialisation. Pulls tuning values from
        the mission config, creates a periodically-refreshed eligibility
        cache, and attaches a 3-second "Set Rally Point" hold action to
        the player.

    Execution: client only, called once after mission init.
*/

if (!hasInterface) exitWith {};

// ======================================================================
// 1. Load config from missionConfigFile >> "PRA3" >> "RallyConfig"
// ======================================================================
private _cfg = missionConfigFile >> "PRA3" >> "RallyConfig";

GVAR(cooldownTime)    = getNumber (_cfg >> "cooldownTime");
GVAR(spawnCount)      = getNumber (_cfg >> "spawnCount");
GVAR(nearPlayerCount) = getNumber (_cfg >> "nearPlayerCount");
GVAR(enemyCheckRadius)= getNumber (_cfg >> "enemyCheckRadius");

if (GVAR(cooldownTime)     <= 0) then { GVAR(cooldownTime)     = 10;  };
if (GVAR(spawnCount)       <= 0) then { GVAR(spawnCount)       = 9;   };
if (GVAR(nearPlayerCount)  <= 0) then { GVAR(nearPlayerCount)  = 1;   };
if (GVAR(enemyCheckRadius) <= 0) then { GVAR(enemyCheckRadius) = 50;  };

diag_log format [
    "[PRA3:Rally] Config — cd:%1s  spawns:%2  nearPlayers:%3  enemyRad:%4",
    GVAR(cooldownTime), GVAR(spawnCount),
    GVAR(nearPlayerCount), GVAR(enemyCheckRadius)
];

// ======================================================================
// 2. Cached canPlace (refreshes every 1.5 s)
// ======================================================================
GVAR(canPlaceCache)      = false;
GVAR(canPlaceCacheExpiry) = 0;

DFUNC(canPlaceCached) = {
    if (diag_tickTime > GVAR(canPlaceCacheExpiry)) then {
        GVAR(canPlaceCache)      = [player] call FUNC(canPlace);
        GVAR(canPlaceCacheExpiry) = diag_tickTime + 1.5;
    };
    GVAR(canPlaceCache)
};

// ======================================================================
// 3. Hold-action: Set Rally Point (3 s)
// ======================================================================
player addAction [
    "<t color='#2196F3'>Set Rally Point</t>",
    {
        // Immediate re-check
        if !([player] call FUNC(canPlace)) exitWith {
            systemChat "Cannot set rally here.";
        };

        if (!isNil QGVAR(setActive) && {GVAR(setActive)}) exitWith {};
        GVAR(setActive) = true;

        private _holdSec = 3;
        private _t0      = diag_tickTime;

        player playMove "AmovPercMstpSnonWnonDnon";

        [{
            params ["_args", "_pfh"];
            _args params ["_t0", "_holdSec"];

            if (!alive player || {vehicle player != player}) exitWith {
                GVAR(setActive) = false;
                hintSilent "";
                [_pfh] call PRA3_fw_removePFH;
                systemChat "Rally placement interrupted.";
            };

            private _dt  = diag_tickTime - _t0;
            private _pct = (_dt / _holdSec) min 1;

            private _filled = floor (_pct * 20);
            private _bar = "";
            for "_j" from 1 to _filled do { _bar = _bar + "|"; };
            hintSilent format ["Setting Rally  [%1] %2%%", _bar, floor (_pct * 100)];

            if (_dt >= _holdSec) exitWith {
                GVAR(setActive) = false;
                hintSilent "";
                [_pfh] call PRA3_fw_removePFH;

                // Forward placement to the server
                [player] remoteExecCall [QFUNC(place), 2];
                diag_log format ["[PRA3:Rally] Set rally hold done by %1", name player];
            };
        }, 0.1, [_t0, _holdSec]] call PRA3_fw_addPFH;
    },
    nil,
    6,
    false,
    true,
    "",
    "call " + QFUNC(canPlaceCached)
];

// ======================================================================
// 4. Notification listeners
// ======================================================================
["rallySet", {
    params ["_locName"];
    systemChat format ["Rally point set near %1.", _locName];
}] call PRA3_fw_addHandler;

["rallyLost", {
    params [["_reason", "unknown"]];
    private _txt = switch (_reason) do {
        case "enemy":    { "Rally overrun by enemies!" };
        case "disbanded": { "Rally lost — squad disbanded." };
        default          { "Rally point destroyed." };
    };
    systemChat _txt;
}] call PRA3_fw_addHandler;

diag_log "[PRA3:Rally] Client setup finished.";
