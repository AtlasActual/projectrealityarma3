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
        0
    }];
};

// ======================================================================
// 8. Fire "missionStarted" event when the mission is live
// ======================================================================
if (time > 0) then {
    // Mission is already running (e.g. JIP)
    ["missionStarted", []] call FWFUNC(fireEvent);
} else {
    // Mission just loaded -- wait for first frame
    addMissionEventHandler ["Loaded", {
        removeMissionEventHandler ["Loaded", _thisEventHandler];
        ["missionStarted", []] call FWFUNC(fireEvent);
    }];

    // Also handle the normal (non-save-load) start via EachFrame
    [{
        if (time > 0) then {
            removeMissionEventHandler ["Loaded", -1]; // clean up if Loaded was not used
            ["missionStarted", []] call FWFUNC(fireEvent);
        };
    }, 0, []] call FWFUNC(execNextFrame);
};

// ======================================================================
// 9. Server: forward entity creation through the event bus
// ======================================================================
if (isServer) then {
    addMissionEventHandler ["EntityCreated", {
        params ["_entity"];
        ["entityCreated", [_entity]] call FWFUNC(fireEvent);
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

diag_log "[PRA3 Common] Init complete.";
