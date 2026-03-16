#include "script_component.hpp"
/*
    FUNC(changeSide)

    Description:
        Transfers a player to a new side. Reads the appropriate unit class
        from missionConfigFile >> "PRA3" >> "Factions" >> str(_targetSide),
        spawns a fresh unit of that class in a dedicated group, copies
        every non-engine variable, re-attaches triggers, preserves the
        vehicleVarName, hands player control to the new unit, fires the
        relevant network events, and schedules the old unit for deletion.

    Params:
        0: _unit       - OBJECT - current player unit
        1: _targetSide - SIDE   - side the player should move to

    Returns:
        OBJECT - the newly created unit on _targetSide
*/

params ["_unit", "_targetSide"];

// ---- 1. Resolve class from mission config ----
private _sideConfig = missionConfigFile >> "PRA3" >> "Factions" >> str _targetSide;
private _unitClass  = getText (_sideConfig >> "playerClass");

if (_unitClass isEqualTo "") exitWith {
    diag_log format [
        "[PRA3 Respawn] changeSide aborted -- no playerClass for side %1",
        _targetSide
    ];
    _unit
};

// ---- 2. Spawn new unit ----
private _grp = createGroup [_targetSide, true];
private _posOld = getPosATL _unit;

private _newUnit = _grp createUnit [_unitClass, _posOld, [], 0, "NONE"];
_newUnit setPosATL _posOld;
_newUnit setDir (getDir _unit);

// ---- 3. Migrate variables ----
//       Skip anything beginning with engine-reserved prefixes
private _blockedPrefixes = ["BIS_fnc_", "bis_fnc_"];

{
    private _vName = _x;
    private _vVal  = _unit getVariable _vName;

    private _blocked = false;
    {
        if (_vName find _x == 0) exitWith { _blocked = true };
    } forEach _blockedPrefixes;

    if (!_blocked && {!isNil "_vVal"}) then {
        _newUnit setVariable [_vName, _vVal, true];
    };
} forEach (allVariables _unit);

// ---- 4. Re-attach triggers ----
{
    if (triggerAttachedVehicle _x isEqualTo _unit) then {
        _x triggerAttachVehicle [_newUnit];
    };
} forEach (allMissionObjects "EmptyDetector");

// ---- 5. Preserve vehicleVarName ----
private _vehVarName = vehicleVarName _unit;
if (_vehVarName != "") then {
    _newUnit setVehicleVarName _vehVarName;
    missionNamespace setVariable [_vehVarName, _newUnit, true];
};

// ---- 6. Hand control to the new unit ----
selectPlayer _newUnit;

// ---- 7. Fire events ----
["playerChanged", [_newUnit, _unit]] call PRA3_fw_fireGlobal;
["playerRespawned", [_newUnit, _unit]] call PRA3_fw_fireEvent;

diag_log format [
    "[PRA3 Respawn] %1 moved from %2 to %3 (class %4, unit %5)",
    name _newUnit,
    side group _unit,
    _targetSide,
    _unitClass,
    _newUnit
];

// ---- 8. Deferred cleanup of old unit ----
private _deadRef = _unit;
[{
    params ["_old"];
    if (!isNull _old) then { deleteVehicle _old };
}, 0.1, [_deadRef]] call PRA3_fw_waitAndExec;

_newUnit
