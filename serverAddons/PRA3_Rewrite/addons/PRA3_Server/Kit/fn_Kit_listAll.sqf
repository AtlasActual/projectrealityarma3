#include "script_component.hpp"
/*
    FUNC(listAll)

    Description:
        Returns an array of all kit config entries for the given side.
        Reads from missionConfigFile >> "PRA3" >> "Sides" >> str(side) >> "kits".
        Each entry is [className, configPath].

    Params:
        0: _side - SIDE - the faction side to list kits for

    Returns:
        ARRAY of [STRING className, CONFIG configPath]
*/

params ["_side"];

private _sideStr = str _side;
private _kitsRoot = missionConfigFile >> "PRA3" >> "Sides" >> _sideStr >> "kits";
private _result = [];

if (!isClass _kitsRoot) exitWith {
    diag_log format ["[PRA3 Kit] listAll: no kits config found for side %1", _sideStr];
    _result
};

private _kitCount = count _kitsRoot;

for "_i" from 0 to (_kitCount - 1) do {
    private _entry = _kitsRoot select _i;

    if (isClass _entry) then {
        private _className = configName _entry;
        _result pushBack [_className, _entry];
    };
};

_result
