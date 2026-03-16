#include "script_component.hpp"
/*
    FUNC(canChangeSide)

    Description:
        Determines whether the calling player is permitted to switch
        to the opposing side. Checks the cooldown timer and verifies
        that the team balance would not be violated (the target side
        must not exceed the current side's count by more than the
        configured restrictionCount threshold).

    Parameters: none

    Returns: bool - true if the player may switch sides
*/

// Check cooldown timer
if (time < GVAR(switchUnlockTime)) exitWith {
    false
};

// Determine the competing sides
private _sides = missionNamespace getVariable [QEGVAR(Common,competingSides), []];
if (count _sides < 2) exitWith { false };

private _playerSide = side group player;

// Count players on each side
private _playerSideCount = 0;
private _enemySideCount  = 0;

{
    private _unitSide = side group _x;
    if (_unitSide isEqualTo _playerSide) then {
        _playerSideCount = _playerSideCount + 1;
    } else {
        if (_unitSide in _sides) then {
            _enemySideCount = _enemySideCount + 1;
        };
    };
} forEach allPlayers;

// After switching, the enemy side gains one and our side loses one
private _projectedEnemy  = _enemySideCount + 1;
private _projectedPlayer = _playerSideCount - 1;

// The difference must stay within the restriction threshold
private _maxDifference = GVAR(restrictionCount);

if ((_projectedEnemy - _projectedPlayer) > _maxDifference) exitWith {
    false
};

true
