#include "script_component.hpp"
/*
    FUNC(setData)

    Overwrites a single field inside a deploy point's data record. The
    point must already be registered in storage.

    Arguments:
        0: _pointId    - target point identifier   (String)
        1: _fieldName  - key to modify             (String)
        2: _value      - replacement value         (Any)

    Returns: nothing
*/

params ["_pointId", "_fieldName", "_value"];

private _entry = GVAR(pointStorage) getOrDefault [_pointId, createHashMap];

if (count _entry == 0) exitWith {
    diag_log format ["[PRA3] [Deployment] setData — point '%1' not present in storage", _pointId];
};

_entry set [_fieldName, _value];
