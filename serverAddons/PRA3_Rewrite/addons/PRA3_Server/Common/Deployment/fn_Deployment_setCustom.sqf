#include "script_component.hpp"
/*
    FUNC(setCustom)

    Writes a key-value pair into the customData HashMap that lives inside a
    deploy point's record. If customData was somehow lost or overwritten with
    a non-HashMap value, a fresh HashMap is re-attached to the record first.

    Arguments:
        0: _pointId  - target point identifier             (String)
        1: _key      - key to write inside customData      (String)
        2: _value    - value to associate with the key     (Any)

    Returns: nothing
*/

params ["_pointId", "_key", "_value"];

private _entry = GVAR(pointStorage) getOrDefault [_pointId, createHashMap];

if (count _entry == 0) exitWith {
    diag_log format ["[PRA3] [Deployment] setCustom — point '%1' not present in storage", _pointId];
};

private _cData = _entry getOrDefault ["customData", createHashMap];

// Guard: if the stored customData is not actually a HashMap, replace it
if !(_cData isEqualType createHashMap) then {
    _cData = createHashMap;
    _entry set ["customData", _cData];
};

_cData set [_key, _value];
