#include "script_component.hpp"
/*
    FUNC(removePoint)

    Unregisters a deploy point. Any world objects attached to the point are
    deleted first, then the record is purged from storage and all machines
    are notified via the "deployPointRemoved" event.

    Arguments:
        0: _pointId  - identifier of the point to destroy  (String)

    Returns: nothing
*/

params ["_pointId"];

private _entry = GVAR(pointStorage) getOrDefault [_pointId, createHashMap];

if (count _entry == 0) exitWith {
    diag_log format ["[PRA3] [Deployment] removePoint — '%1' does not exist, skipping", _pointId];
};

// Destroy every linked world object that is still alive
private _linkedObjs = _entry getOrDefault ["objects", []];
{
    if !(isNull _x) then {
        deleteVehicle _x;
    };
} forEach _linkedObjs;

// Purge the record
GVAR(pointStorage) deleteAt _pointId;

// Let every machine know the point is gone
["deployPointRemoved", [_pointId]] call FWFUNC(fireGlobal);

diag_log format ["[PRA3] [Deployment] Removed point '%1'", _pointId];
