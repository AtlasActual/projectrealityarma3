#include "script_component.hpp"
/*
    FUNC(consumeSpawn)

    Uses one spawn ticket from a deploy point. Points with unlimited
    tickets (-1) are returned as-is without modification. Finite tickets
    are decremented by one; if the count drops to zero the point is
    automatically removed. A "ticketsChanged" event is broadcast globally
    whenever the count changes.

    Arguments:
        0: _pointId  - identifier of the point to consume from  (String)

    Returns:
        The point's position [x,y,z], or [] when the point does not exist
*/

params ["_pointId"];

private _entry = GVAR(pointStorage) getOrDefault [_pointId, createHashMap];

if (count _entry == 0) exitWith {
    diag_log format ["[PRA3] [Deployment] consumeSpawn — point '%1' does not exist", _pointId];
    []
};

private _pos     = _entry get "position";
private _tickets = _entry get "spawnTickets";

// Unlimited tickets — return position without touching the counter
if (_tickets == -1) exitWith { _pos };

// Subtract one ticket
_tickets = _tickets - 1;
_entry set ["spawnTickets", _tickets];

if (_tickets <= 0) then {
    diag_log format ["[PRA3] [Deployment] Point '%1' has no tickets left — destroying", _pointId];
    [_pointId] call FUNC(removePoint);
} else {
    // Inform every machine about the updated ticket count
    ["ticketsChanged", [_pointId]] call FWFUNC(fireGlobal);
};

_pos
