#include "script_component.hpp"
/*
    FUNC(details)

    Description:
        Reads kit configuration and returns either a specific property
        or a complete HashMap of all kit properties.

    Params:
        0: _kitConfig    - CONFIG - config path to the kit entry
        1: _propertyName - STRING - (optional) specific property to return

    Returns:
        If _propertyName given: the value of that property
        Otherwise: HASHMAP of all kit properties
*/

params ["_kitConfig", ["_propertyName", ""]];

// Helper to read a config array or return default empty array
private _fnc_getArr = {
    params ["_cfg", "_key"];
    private _node = _cfg >> _key;
    if (isArray _node) then {
        getArray _node
    } else {
        []
    };
};

// Helper to read a config text or return default empty string
private _fnc_getTxt = {
    params ["_cfg", "_key"];
    private _node = _cfg >> _key;
    if (isText _node) then {
        getText _node
    } else {
        ""
    };
};

// Helper to read a config number or return default
private _fnc_getNum = {
    params ["_cfg", "_key", ["_default", 0]];
    private _node = _cfg >> _key;
    if (isNumber _node) then {
        getNumber _node
    } else {
        _default
    };
};

// Build the full property map
private _buildMap = {
    private _map = createHashMap;

    _map set ["displayName",   [_kitConfig, "displayName"] call _fnc_getTxt];
    _map set ["icon",          [_kitConfig, "icon"] call _fnc_getTxt];

    _map set ["weapons",       [_kitConfig, "weapons"] call _fnc_getArr];
    _map set ["magazines",     [_kitConfig, "magazines"] call _fnc_getArr];
    _map set ["items",         [_kitConfig, "items"] call _fnc_getArr];

    _map set ["uniform",       [_kitConfig, "uniform"] call _fnc_getTxt];
    _map set ["vest",          [_kitConfig, "vest"] call _fnc_getTxt];
    _map set ["backpack",      [_kitConfig, "backpack"] call _fnc_getTxt];
    _map set ["headgear",      [_kitConfig, "headgear"] call _fnc_getTxt];

    _map set ["assignedItems", [_kitConfig, "assignedItems"] call _fnc_getArr];

    // Trait booleans
    private _traits = createHashMap;
    private _traitsCfg = _kitConfig >> "traits";

    _traits set ["isLeader",   [_traitsCfg, "isLeader",   0] call _fnc_getNum];
    _traits set ["isMedic",    [_traitsCfg, "isMedic",    0] call _fnc_getNum];
    _traits set ["isEngineer", [_traitsCfg, "isEngineer", 0] call _fnc_getNum];
    _traits set ["isPilot",    [_traitsCfg, "isPilot",    0] call _fnc_getNum];
    _traits set ["isCrew",     [_traitsCfg, "isCrew",     0] call _fnc_getNum];

    _map set ["traits", _traits];

    // Squad/team limits
    _map set ["kitGroup",    [_kitConfig, "kitGroup"] call _fnc_getTxt];
    _map set ["maxPerSquad", [_kitConfig, "maxPerSquad", -1] call _fnc_getNum];
    _map set ["maxPerTeam",  [_kitConfig, "maxPerTeam",  -1] call _fnc_getNum];

    _map
};

// Return specific property or full map
if (_propertyName isNotEqualTo "") then {
    private _map = call _buildMap;
    _map getOrDefault [_propertyName, nil]
} else {
    call _buildMap
};
