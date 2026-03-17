#include "script_component.hpp"
/*
    PRA3_fnc_fw_utilities

    Description:
        General-purpose utility functions used across the framework.
        Provides spatial queries, logic group management, config loading,
        and safe position finding.

    Called during framework bootstrap.
*/

// ------------------------------------------------------------------
// PRA3_fw_getNearUnits
//   Params: [position, radius]
//   Returns: array of alive, non-captive units within radius
// ------------------------------------------------------------------
GVAR(getNearUnits) = {
    params ["_pos", "_radius"];

    private _result = (_pos nearEntities ["CAManBase", _radius]) select {alive _x && !captive _x};

    _result
};

// ------------------------------------------------------------------
// PRA3_fw_getLogicGroup
//   Returns: a persistent group on sideLogic for spawning logic objects.
//   Creates the group on first call, reuses it thereafter.
// ------------------------------------------------------------------
GVAR(logicGroup) = grpNull;

GVAR(getLogicGroup) = {
    if (isNull GVAR(logicGroup)) then {
        GVAR(logicGroup) = createGroup [sideLogic, true];
    };

    GVAR(logicGroup)
};

// ------------------------------------------------------------------
// PRA3_fw_loadSettings
//   Params: [varName, configPath]
//   Reads all sub-entries from the given config path into a HashMap
//   and stores it in the variable named by varName (via missionNamespace).
//   Each config entry becomes key -> value in the HashMap.
//   Returns: the created HashMap
// ------------------------------------------------------------------
GVAR(loadSettings) = {
    params ["_varName", "_configPath"];

    private _cfg = configFile >> _configPath;
    private _map = createHashMap;

    if (isNull _cfg) exitWith {
        diag_log format ["[PRA3] loadSettings: config path '%1' not found", _configPath];
        missionNamespace setVariable [_varName, _map];
        _map
    };

    private _count = count _cfg;

    for "_i" from 0 to (_count - 1) do {
        private _entry = _cfg select _i;
        private _key = configName _entry;

        private _val = if (isNumber _entry) then {
            getNumber _entry
        } else {
            if (isText _entry) then {
                getText _entry
            } else {
                if (isArray _entry) then {
                    getArray _entry
                } else {
                    nil
                };
            };
        };

        if (!isNil "_val") then {
            _map set [_key, _val];
        };
    };

    missionNamespace setVariable [_varName, _map];

    _map
};

// ------------------------------------------------------------------
// PRA3_fw_safePos
//   Params: [position, radius]
//   Returns: a safe empty position near the given one.
//   Uses findEmptyPosition to locate a spot free of objects.
//   Falls back to the original position if none found.
// ------------------------------------------------------------------
GVAR(safePos) = {
    params ["_pos", ["_radius", 50]];

    private _found = _pos findEmptyPosition [0, _radius];

    if (_found isEqualTo []) then {
        _pos
    } else {
        _found
    };
};

diag_log "[PRA3] Utility functions initialized";
