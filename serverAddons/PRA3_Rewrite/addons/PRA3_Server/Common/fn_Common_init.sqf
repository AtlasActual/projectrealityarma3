#include "script_component.hpp"
/*
    PRA3_fnc_Common_init

    Description:
        PreInit entry point for the Common module. Runs before all other
        modules to bootstrap the framework, read mission configuration,
        build lookup tables, suppress AI chatter, and wire up core
        mission event handlers.

    Called during CfgFunctions preInit.
*/

// ======================================================================
// 1. Bootstrap the framework (must happen first)
// ======================================================================
[] call FWFUNC(bootstrap);

// ======================================================================
// 2. Read version information from mission config
// ======================================================================
private _versionCfg = missionConfigFile >> "PRA3" >> "version";
if (isText _versionCfg) then {
    GVAR(version) = getText _versionCfg;
} else {
    GVAR(version) = "unknown";
};

diag_log format ["[PRA3 Common] Version: %1", GVAR(version)];

// ======================================================================
// 3. Read competing sides from mission config and resolve to side values
// ======================================================================
private _sideStrings = getArray (missionConfigFile >> "PRA3" >> "sides");
private _resolvedSides = [];

{
    private _sideVal = switch (toLower _x) do {
        case "west":        { west };
        case "blufor":      { west };
        case "east":        { east };
        case "opfor":       { east };
        case "independent": { independent };
        case "resistance":  { independent };
        case "guerrilla":   { independent };
        case "civilian":    { civilian };
        default             { sideUnknown };
    };

    if !(_sideVal isEqualTo sideUnknown) then {
        _resolvedSides pushBackUnique _sideVal;
    } else {
        diag_log format ["[PRA3 Common] WARNING: Unrecognised side string '%1'", _x];
    };
} forEach _sideStrings;

GVAR(competingSides) = _resolvedSides;

diag_log format ["[PRA3 Common] Competing sides: %1", GVAR(competingSides)];

// ======================================================================
// 4. Build marker-name to position hashmap for location lookups
// ======================================================================
GVAR(markerPositions) = createHashMap;

{
    private _mName = _x;
    private _mText = markerText _mName;
    if (_mText != "") then {
        GVAR(markerPositions) set [_mText, markerPos _mName];
    };
} forEach allMapMarkers;

// ======================================================================
// 5. Cache all location type class names from CfgLocationTypes
// ======================================================================
GVAR(locationTypes) = [];

private _locTypeCfg = configFile >> "CfgLocationTypes";
for "_i" from 0 to (count _locTypeCfg - 1) do {
    private _entry = _locTypeCfg select _i;
    if (isClass _entry) then {
        GVAR(locationTypes) pushBack (configName _entry);
    };
};

// ======================================================================
// 6. Disable AI radio chatter globally
// ======================================================================
enableSentences false;

// ======================================================================
// 7. Client-side: suppress negative rating from teamkills / friendly fire
// ======================================================================
if (hasInterface) then {
    addMissionEventHandler ["HandleRating", {
        params ["_unit", "_rating"];
        if (_rating < 0) then { 0 } else { _rating }
    }];
};

// ======================================================================
// 8. Fire "missionStarted" event when the mission is live
// ======================================================================
GVAR(missionStartFired) = false;

addMissionEventHandler ["Loaded", {
    removeMissionEventHandler ["Loaded", _thisEventHandler];
    if (!GVAR(missionStartFired)) then {
        GVAR(missionStartFired) = true;
        ["missionStarted", []] call FWFUNC(fireEvent);
    };
}];

[{
    if (time > 0) then {
        if (!GVAR(missionStartFired)) then {
            GVAR(missionStartFired) = true;
            ["missionStarted", []] call FWFUNC(fireEvent);
        };
    };
}, 0, []] call FWFUNC(execNextFrame);

// ======================================================================
// 9. Server: forward entity creation through the event bus
// ======================================================================
if (isServer) then {
    addMissionEventHandler ["EntityCreated", {
        params ["_entity"];
        ["entityCreated", [_entity]] call FWFUNC(fireEvent);
    }];

    addMissionEventHandler ["EntityKilled", {
        params ["_killed", "_killer", "_instigator"];
        ["entityKilled", [_killed, _killer, _instigator]] call FWFUNC(fireEvent);
    }];
};

// ======================================================================
// 10. Client: track player side changes via a per-frame handler
// ======================================================================
if (hasInterface) then {
    GVAR(lastKnownSide) = sideUnknown;

    [{
        params ["_args", "_pfhId"];

        if (isNull player) exitWith {};

        private _currentSide = side group player;

        if !(_currentSide isEqualTo GVAR(lastKnownSide)) then {
            private _previousSide = GVAR(lastKnownSide);
            GVAR(lastKnownSide) = _currentSide;

            // Only fire the event after the initial detection
            if !(_previousSide isEqualTo sideUnknown) then {
                ["sideChanged", [player, _previousSide, _currentSide]] call FWFUNC(fireEvent);
            };

            diag_log format [
                "[PRA3 Common] Player side detected: %1 (was %2)",
                _currentSide,
                _previousSide
            ];
        };
    }, 1, []] call FWFUNC(addPFH);
};

// ======================================================================
// 11. Initialize all PRA3 modules
//     Deployment must be first (other modules depend on pointStorage).
//     Modules with both init and setup functions: init registers handlers,
//     setup runs at missionStarted. Modules with only clientSetup/serverSetup
//     are called directly here.
// ======================================================================

// --- Shared systems (run on all machines) ---
[] call EFUNC(Deployment,setup);
[] call EFUNC(Notification,clientSetup);

// --- Sector and Tickets (have their own init that handles server/client internally) ---
[] call EFUNC(Sector,init);
[] call EFUNC(Tickets,init);

// --- Server-only module setups ---
if (isServer) then {
    [] call EFUNC(Deployment,serverSetup);
    [] call EFUNC(FOB,serverSetup);
    [] call EFUNC(VehicleRespawn,serverSetup);
    [] call EFUNC(Rally,serverSetup);
    [] call EFUNC(Logistic,serverSetup);
    [] call EFUNC(PerformanceInfo,serverSetup);

    diag_log "[PRA3] Server modules initialized.";
};

// --- Client-only module setups ---
if (hasInterface) then {
    [] call EFUNC(Deployment,clientSetup);
    [] call EFUNC(RespawnUI,clientSetup);
    [] call EFUNC(Squad,clientSetup);
    [] call EFUNC(Kit,clientSetup);
    [] call EFUNC(Revive,clientSetup);
    [] call EFUNC(FOB,clientSetup);
    [] call EFUNC(Rally,clientSetup);
    [] call EFUNC(Logistic,clientSetup);
    // Note: Sector_clientSetup is called by Sector_init after setupDone broadcast
    [] call EFUNC(Nametags,clientSetup);
    [] call EFUNC(CompassUI,clientSetup);
    [] call EFUNC(UnitTracker,clientSetup);
    [] call EFUNC(SquadRespawn,clientSetup);
    [] call EFUNC(PerformanceInfo,clientSetup);

    // Bridge engine Killed EH to PRA3 event bus (must be re-added on respawn)
    GVAR(addKilledEH) = {
        params ["_unit"];
        _unit addEventHandler ["Killed", {
            params ["_unit", "_killer", "_instigator", "_useEffects"];
            ["Killed", _this] call FWFUNC(fireEvent);
        }];
    };
    [player] call GVAR(addKilledEH);

    // Re-add Killed EH after each respawn (new unit = new EH needed)
    ["playerRespawned", {
        params ["_newUnit"];
        [_newUnit] call GVAR(addKilledEH);
    }] call FWFUNC(addHandler);

    diag_log "[PRA3] Client modules initialized.";
};

diag_log "[PRA3 Common] Init complete.";
