#include "script_component.hpp"
/*
    FUNC(typeAllowed)

    Description:
        Checks whether the player is permitted to create a squad of
        the given type. Validates against the maximum number of groups
        of that type allowed on the player's side, and whether the
        minimum connected player count threshold is met.

    Parameters:
        _typeName - String identifier of the squad type (e.g. "infantry")

    Returns: bool - true if the type is currently permitted
*/

params ["_typeName"];

// Read type configuration from mission config
private _typeCfg = missionConfigFile >> "PRA3" >> "CfgGroupTypes" >> _typeName;

if (isNull _typeCfg) exitWith {
    diag_log format [
        "[PRA3 Squad] typeAllowed: unknown type '%1'", _typeName
    ];
    false
};

private _maxGroups      = getNumber (_typeCfg >> "maxGroups");
private _minPlayerCount = getNumber (_typeCfg >> "minPlayers");

// Apply defaults
if (_maxGroups isEqualTo 0) then {
    _maxGroups = 99;
};

// Count how many groups of this type exist on the player's side
private _playerSide = playerSide;
private _existingCount = 0;

{
    if (side _x isEqualTo _playerSide) then {
        private _grpType = _x getVariable [QGVAR(type), ""];
        if (_grpType isEqualTo _typeName) then {
            _existingCount = _existingCount + 1;
        };
    };
} forEach allGroups;

// Check against the max groups limit
if (_existingCount >= _maxGroups) exitWith {
    diag_log format [
        "[PRA3 Squad] typeAllowed: '%1' at limit (%2/%3)",
        _typeName, _existingCount, _maxGroups
    ];
    false
};

// Check minimum player threshold on this side
if (_minPlayerCount > 0) then {
    private _sidePlayerCount = {
        side group _x isEqualTo _playerSide
    } count allPlayers;

    if (_sidePlayerCount < _minPlayerCount) exitWith {
        diag_log format [
            "[PRA3 Squad] typeAllowed: '%1' needs %2 players, only %3 present",
            _typeName, _minPlayerCount, _sidePlayerCount
        ];
        false
    };
};

true
