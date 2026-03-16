#include "script_component.hpp"
/*
    FUNC(getCustom)

    Reads a single key from the customData HashMap embedded inside a deploy
    point record.

    Arguments:
        0: _pointId  - target point identifier           (String)
        1: _key      - key to look up inside customData  (String)

    Returns:
        The stored value, or nil when the point or key is absent
*/

params ["_pointId", "_key"];

private _entry = GVAR(pointStorage) getOrDefault [_pointId, createHashMap];

if (count _entry == 0) exitWith {
    diag_log format ["[PRA3] [Deployment] getCustom — point '%1' not present in storage", _pointId];
    nil
};

private _cData = _entry getOrDefault ["customData", createHashMap];

_cData getOrDefault [_key, nil]
