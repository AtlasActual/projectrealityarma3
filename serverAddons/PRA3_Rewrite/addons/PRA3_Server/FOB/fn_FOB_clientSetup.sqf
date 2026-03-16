#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-side FOB module initialisation. Reads FOB configuration
        from the mission config, builds a side-to-box-classname lookup
        map, registers hold-action handlers for building, dismantling,
        destroying, and defusing FOBs, and subscribes to placement
        notification events.

    Called once on each client after mission init.
*/

if (!hasInterface) exitWith {};

// ======================================================================
// 1. Load FOB settings from mission config
// ======================================================================
private _cfgFOB = missionConfigFile >> "PRA3" >> "cfgFOB";

GVAR(minDistance)      = getNumber (_cfgFOB >> "minDistance");
GVAR(maxEnemyDistance) = getNumber (_cfgFOB >> "maxEnemyDistance");
GVAR(maxEnemyCount)    = getNumber (_cfgFOB >> "maxEnemyCount");
GVAR(ticketPenalty)    = getNumber (_cfgFOB >> "ticketPenalty");

// Apply sensible defaults when config values are absent or zero
if (GVAR(minDistance) <= 0)      then { GVAR(minDistance)      = 400; };
if (GVAR(maxEnemyDistance) <= 0) then { GVAR(maxEnemyDistance) = 100; };
if (GVAR(maxEnemyCount) <= 0)    then { GVAR(maxEnemyCount)    = 2;   };
if (GVAR(ticketPenalty) <= 0)    then { GVAR(ticketPenalty)    = 20;  };

diag_log format [
    "[PRA3 FOB] Config loaded — minDist: %1, enemyDist: %2, enemyMax: %3, penalty: %4",
    GVAR(minDistance), GVAR(maxEnemyDistance), GVAR(maxEnemyCount), GVAR(ticketPenalty)
];

// ======================================================================
// 2. Build side -> FOB box classname HashMap
// ======================================================================
GVAR(sideBoxMap) = createHashMap;

private _cfgSides = missionConfigFile >> "PRA3" >> "Sides";

if (!isNull _cfgSides) then {
    for "_i" from 0 to (count _cfgSides - 1) do {
        private _sideCfg = _cfgSides select _i;
        if (!isClass _sideCfg) then { continue };

        private _sideName    = configName _sideCfg;
        private _boxClass    = getText (_sideCfg >> "fobBoxClass");

        if (_boxClass != "") then {
            private _sideVal = switch (toLower _sideName) do {
                case "west":       { west };
                case "blufor":     { west };
                case "east":       { east };
                case "opfor":      { east };
                case "resistance": { resistance };
                case "indep":      { resistance };
                default            { sideUnknown };
            };

            if !(_sideVal isEqualTo sideUnknown) then {
                GVAR(sideBoxMap) set [_sideVal, _boxClass];
            };
        };
    };
};

diag_log format ["[PRA3 FOB] Side box map built — %1 entries", count GVAR(sideBoxMap)];

// ======================================================================
// 3. Cache for canPlace result (refreshed every 2 seconds)
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
// 4. Register hold actions via per-frame handler (check nearby objects)
// ======================================================================

// Build action — register on player
GVAR(buildActionId) = player addAction [
    "<t color='#4CAF50'>Build FOB</t>",
    { [player] call FUNC(buildAction) },
    nil,
    6,
    false,
    true,
    "",
    "call " + QFUNC(canPlaceCached)
];

// Destroy action — targets enemy FOB objects within range
GVAR(destroyActionId) = player addAction [
    "<t color='#F44336'>Destroy FOB</t>",
    { [player] call FUNC(destroyAction) },
    nil,
    5,
    false,
    true,
    "",
    "alive player && {vehicle player == player}"
];

// Defuse action — targets own FOBs under attack
GVAR(defuseActionId) = player addAction [
    "<t color='#FF9800'>Defuse FOB</t>",
    { [player] call FUNC(defuseAction) },
    nil,
    5,
    false,
    true,
    "",
    "alive player && {vehicle player == player}"
];

// Dismantle action — targets own FOBs for voluntary removal
GVAR(dismantleActionId) = player addAction [
    "<t color='#9E9E9E'>Dismantle FOB</t>",
    { [player] call FUNC(dismantleAction) },
    nil,
    4,
    false,
    true,
    "",
    "alive player && {vehicle player == player}"
];

// ======================================================================
// 5. Listen for FOB placement notifications
// ======================================================================
["fobPlaced", {
    params ["_squadId", "_locationName"];

    private _msg = format ["FOB has been established near %1", _locationName];
    systemChat _msg;

    diag_log format ["[PRA3 FOB] Notification — squad %1 placed FOB near %2", _squadId, _locationName];
}] call PRA3_fw_addHandler;

diag_log "[PRA3 FOB] Client setup complete.";
