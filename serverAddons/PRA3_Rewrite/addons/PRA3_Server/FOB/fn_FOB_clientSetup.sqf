#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Initialises the FOB module on each client machine. Loads tuning
        parameters from the mission config, constructs a per-side lookup
        table that maps each faction to its FOB composition class and
        supply-box classname, sets up a periodically-refreshed placement
        eligibility cache, and attaches four hold-actions to the player
        for building, demolishing, defusing, and dismantling FOBs.

    Execution: client only, called once after mission init.
*/

if (!hasInterface) exitWith {};

// ======================================================================
// 1. Read tuning parameters from missionConfigFile >> "PRA3" >> "CfgFOB"
// ======================================================================
private _cfg = missionConfigFile >> "PRA3" >> "CfgFOB";

GVAR(minDistance)       = getNumber (_cfg >> "minDistance");
GVAR(maxEnemyToPlace)   = getNumber (_cfg >> "maxEnemyToPlace");
GVAR(ticketPenalty)     = getNumber (_cfg >> "ticketPenalty");

// Sensible defaults when the config entry is missing or zero
if (GVAR(minDistance)     <= 0) then { GVAR(minDistance)     = 600; };
if (GVAR(maxEnemyToPlace) <= 0) then { GVAR(maxEnemyToPlace) = 5;   };
if (GVAR(ticketPenalty)   <= 0) then { GVAR(ticketPenalty)   = 20;  };

diag_log format [
    "[PRA3:FOB] Config — minDist:%1  maxEnemy:%2  penalty:%3",
    GVAR(minDistance), GVAR(maxEnemyToPlace), GVAR(ticketPenalty)
];

// ======================================================================
// 2. Build side -> { compositionClass, boxClass } HashMap
// ======================================================================
GVAR(sideData) = createHashMap;

private _cfgSides = missionConfigFile >> "PRA3" >> "Sides";
if (!isNull _cfgSides) then {
    for "_idx" from 0 to (count _cfgSides - 1) do {
        private _entry = _cfgSides select _idx;
        if (!isClass _entry) then { continue };

        private _sName = configName _entry;
        private _compClass = getText (_entry >> "fobCompositionClass");
        private _boxClass  = getText (_entry >> "fobBoxClass");

        private _sideVal = switch (toLower _sName) do {
            case "west":       { west };
            case "blufor":     { west };
            case "east":       { east };
            case "opfor":      { east };
            case "resistance": { resistance };
            case "indep":      { resistance };
            default            { sideUnknown };
        };

        if !(_sideVal isEqualTo sideUnknown) then {
            private _rec = createHashMap;
            _rec set ["compositionClass", _compClass];
            _rec set ["boxClass", _boxClass];
            GVAR(sideData) set [_sideVal, _rec];
        };
    };
};

diag_log format ["[PRA3:FOB] sideData built — %1 entries", count GVAR(sideData)];

// ======================================================================
// 3. Cached placement eligibility (refreshed every 2 s)
// ======================================================================
GVAR(canPlaceCache)      = false;
GVAR(canPlaceCacheExpiry) = 0;

DFUNC(canPlaceCached) = {
    if (diag_tickTime > GVAR(canPlaceCacheExpiry)) then {
        GVAR(canPlaceCache)      = [player] call FUNC(canPlace);
        GVAR(canPlaceCacheExpiry) = diag_tickTime + 2;
    };
    GVAR(canPlaceCache)
};

// ======================================================================
// 4. Hold-action: Build FOB
// ======================================================================
player addAction [
    "<t color='#4CAF50'>Build FOB</t>",
    { [player] call FUNC(buildAction) },
    nil,
    6,
    false,
    true,
    "",
    "call " + QFUNC(canPlaceCached)
];

// ======================================================================
// 5. Hold-action: Demolish enemy FOB
// ======================================================================
player addAction [
    "<t color='#F44336'>Demolish FOB</t>",
    { [player] call FUNC(destroyAction) },
    nil,
    5,
    false,
    true,
    "",
    "alive player && {vehicle player == player}"
];

// ======================================================================
// 6. Hold-action: Defuse own FOB (cancel enemy destruction timer)
// ======================================================================
player addAction [
    "<t color='#FF9800'>Defuse FOB</t>",
    { [player] call FUNC(defuseAction) },
    nil,
    5,
    false,
    true,
    "",
    "alive player && {vehicle player == player}"
];

// ======================================================================
// 7. Hold-action: Dismantle own FOB (voluntary removal)
// ======================================================================
player addAction [
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
// 8. Subscribe to placement notifications
// ======================================================================
["fobPlaced", {
    params ["_squadName", "_locName"];
    systemChat format ["%1 established a FOB near %2", _squadName, _locName];
}] call PRA3_fw_addHandler;

diag_log "[PRA3:FOB] Client setup finished.";
