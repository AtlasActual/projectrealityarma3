#include "script_component.hpp"
/*
    FUNC(changeSide)

    Description:
        Switches the calling player to the opposing side. First
        validates the switch via FUNC(canChangeSide), then determines
        the target side from the competing sides list, delegates the
        actual respawn-side change to the Respawn module, and applies
        a cooldown timer.

    Parameters: none
*/

// Validate that the switch is allowed
private _canSwitch = [] call FUNC(canChangeSide);

if (!_canSwitch) exitWith {
    // Determine reason for the block and notify the player
    if (time < GVAR(switchUnlockTime)) then {
        private _remaining = ceil (GVAR(switchUnlockTime) - time);
        systemChat format [
            "You must wait %1 seconds before switching sides again.",
            _remaining
        ];
    } else {
        systemChat "Cannot switch sides: teams would become unbalanced.";
    };

    diag_log format [
        "[PRA3 Squad] Side change denied for %1",
        name player
    ];
};

// Determine the target (opposite) side
private _sides = EGVAR(Common,competingSides);
private _playerSide = side group player;
private _targetSide = sideUnknown;

{
    if (!(_x isEqualTo _playerSide)) exitWith {
        _targetSide = _x;
    };
} forEach _sides;

if (_targetSide isEqualTo sideUnknown) exitWith {
    diag_log "[PRA3 Squad] changeSide: could not determine target side.";
};

// Delegate to the Respawn module for the actual side transition
[_targetSide] call EFUNC(Respawn,changeSide);

// Apply cooldown so the player cannot rapidly switch back
GVAR(switchUnlockTime) = time + GVAR(restrictionTime);

systemChat format [
    "You have switched to %1.",
    _targetSide
];

diag_log format [
    "[PRA3 Squad] %1 switched from %2 to %3 (locked until T+%4)",
    name player, _playerSide, _targetSide, GVAR(switchUnlockTime)
];
