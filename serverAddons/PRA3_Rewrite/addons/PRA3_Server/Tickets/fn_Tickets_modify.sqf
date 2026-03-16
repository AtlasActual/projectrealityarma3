#include "script_component.hpp"
/*
    FUNC(modify)

    Description:
        Adds or subtracts tickets for a given side. Updates the
        missionNamespace variable, broadcasts it to all machines,
        and fires the "ticketsChanged" event globally.

    Parameters:
        _side   - Side whose tickets to modify (e.g. west, east)
        _amount - Number to add (positive) or subtract (negative)

    Returns: new ticket count for the side
*/

params ["_side", "_amount"];

private _varName = format [QGVAR(count_%1), _side];
private _current = missionNamespace getVariable [_varName, 0];

// Apply the modification, clamping at zero minimum
private _newCount = (_current + _amount) max 0;

missionNamespace setVariable [_varName, _newCount];
publicVariable _varName;

// Notify all machines of the change
["ticketsChanged", [_side, _newCount]] call PRA3_fw_fireGlobal;

diag_log format [
    "[PRA3 Tickets] %1: %2 -> %3 (delta: %4)",
    _side, _current, _newCount, _amount
];

_newCount
