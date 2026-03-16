#include "script_component.hpp"
/*
    FUNC(getData)

    Retrieves one field (or the full record) from a deploy point. Passing
    "all" as the field name returns the complete HashMap; any other string
    fetches that single key's value.

    Arguments:
        0: _pointId    - target point identifier            (String)
        1: _fieldName  - key to retrieve, or "all"          (String, default "all")

    Returns:
        Requested value, full HashMap, or nil when the point is missing
*/

params ["_pointId", ["_fieldName", "all"]];

private _entry = GVAR(pointStorage) getOrDefault [_pointId, createHashMap];

if (count _entry == 0) exitWith {
    diag_log format ["[PRA3] [Deployment] getData — point '%1' not present in storage", _pointId];
    nil
};

if (_fieldName isEqualTo "all") exitWith { _entry };

_entry getOrDefault [_fieldName, nil]
