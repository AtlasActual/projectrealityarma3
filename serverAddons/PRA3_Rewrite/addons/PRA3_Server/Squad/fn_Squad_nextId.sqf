#include "script_component.hpp"
/*
    FUNC(nextId)

    Description:
        Finds the next available squad name from the NATO phonetic
        alphabet pool that is not currently in use by any group on
        the player's side.

    Parameters: none

    Returns: string - the first unused squad name, or "Squad" as
             a fallback if all names are exhausted.
*/

private _playerSide = playerSide;

// Collect all group IDs currently in use on this side
private _usedNames = [];
{
    if (side _x isEqualTo _playerSide) then {
        _usedNames pushBack (groupId _x);
    };
} forEach allGroups;

// Find the first phonetic name not already taken
private _result = "";

{
    if !(_x in _usedNames) exitWith {
        _result = _x;
    };
} forEach GVAR(squadNames);

// Fallback if every phonetic name is occupied
if (_result isEqualTo "") then {
    _result = format ["Squad-%1", floor (random 9000 + 1000)];
    diag_log "[PRA3 Squad] WARNING: all phonetic names exhausted, using random ID.";
};

_result
