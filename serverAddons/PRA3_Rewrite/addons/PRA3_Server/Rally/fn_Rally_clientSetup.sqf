#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-side rally point module initialisation. Reads rally
        configuration from the mission config (cooldown time, spawn
        count, near-player thresholds), sets up a cached canPlace
        check, and registers the "Set Rally" hold action on the player.

    Called once on each client after mission init.
*/

if (!hasInterface) exitWith {};

// ======================================================================
// 1. Load rally point settings from mission config
// ======================================================================
private _cfgRally = missionConfigFile >> "PRA3" >> "cfgSquadRallyPoint";

GVAR(cooldownTime)        = getNumber (_cfgRally >> "cooldownTime");
GVAR(spawnCount)          = getNumber (_cfgRally >> "spawnCount");
GVAR(nearPlayerThreshold) = getNumber (_cfgRally >> "nearPlayerThreshold");
GVAR(nearPlayerCount)     = getNumber (_cfgRally >> "nearPlayerCount");

// Apply sensible defaults when config values are absent or zero
if (GVAR(cooldownTime) <= 0)        then { GVAR(cooldownTime)        = 120; };
if (GVAR(spawnCount) <= 0)          then { GVAR(spawnCount)          = 9;   };
if (GVAR(nearPlayerThreshold) <= 0) then { GVAR(nearPlayerThreshold) = 10;  };
if (GVAR(nearPlayerCount) <= 0)     then { GVAR(nearPlayerCount)     = 2;   };

diag_log format [
    "[PRA3 Rally] Config loaded — cooldown: %1s, spawns: %2, threshold: %3m, minPlayers: %4",
    GVAR(cooldownTime), GVAR(spawnCount), GVAR(nearPlayerThreshold), GVAR(nearPlayerCount)
];

// ======================================================================
// 2. Cached canPlace result (refreshed every 2 seconds)
// ======================================================================
GVAR(canPlaceCache)     = false;
GVAR(canPlaceCacheTime) = 0;

DFUNC(canPlaceCached) = {
    if (diag_tickTime > GVAR(canPlaceCacheTime)) then {
        GVAR(canPlaceCache)     = [player] call FUNC(canPlace);
        GVAR(canPlaceCacheTime) = diag_tickTime + 2;
    };
    GVAR(canPlaceCache)
};

// ======================================================================
// 3. Register "Set Rally" hold action on the player
// ======================================================================
GVAR(rallyActionId) = player addAction [
    "<t color='#2196F3'>Set Rally Point</t>",
    {
        params ["_target", "_caller"];

        // Five-second hold action implemented via PFH
        private _holdDuration = 5;
        private _startTime    = diag_tickTime;

        GVAR(rallyInProgress) = true;

        _caller playMove "AmovPercMstpSnonWnonDnon";

        [{
            params ["_args", "_pfhId"];
            _args params ["_caller", "_startTime", "_holdDuration"];

            // Abort conditions
            if (!alive _caller
                || {vehicle _caller != _caller}
                || {!GVAR(rallyInProgress)}) exitWith {

                GVAR(rallyInProgress) = false;
                [_pfhId] call PRA3_fw_removePFH;
                systemChat "Rally placement cancelled.";
            };

            private _elapsed  = diag_tickTime - _startTime;
            private _progress = _elapsed / _holdDuration;

            private _barLen  = floor (_progress * 20);
            private _barFill = "";
            for "_i" from 1 to _barLen do { _barFill = _barFill + "|"; };
            hintSilent format ["Setting Rally [%1] %2%%", _barFill, floor (_progress * 100)];

            if (_elapsed >= _holdDuration) exitWith {
                GVAR(rallyInProgress) = false;
                [_pfhId] call PRA3_fw_removePFH;
                hintSilent "";

                // Forward the placement to the server under the respawn mutex
                ["respawn", FUNC(place), [_caller], _caller] call PRA3_fw_mutexLock;

                diag_log format ["[PRA3 Rally] Set rally action completed by %1", name _caller];
            };
        }, 0.1, [_caller, _startTime, _holdDuration]] call PRA3_fw_addPFH;
    },
    nil,
    6,
    false,
    true,
    "",
    "call " + QFUNC(canPlaceCached)
];

// ======================================================================
// 4. Listen for rally placement notifications
// ======================================================================
["rallyPlaced", {
    systemChat "Squad rally point has been set.";
}] call PRA3_fw_addHandler;

// ======================================================================
// 5. Listen for rally destruction notifications
// ======================================================================
["rallyDestroyed", {
    params ["_reason"];

    private _msg = switch (_reason) do {
        case "enemy":  { "Rally point overrun by enemies!" };
        case "empty":  { "Rally point lost — squad disbanded." };
        default        { "Rally point has been destroyed." };
    };

    systemChat _msg;
}] call PRA3_fw_addHandler;

diag_log "[PRA3 Rally] Client setup complete.";
