#include "script_component.hpp"
/*
    FUNC(unloadAction)

    Description:
        Unloads unconscious units from a vehicle. Finds all unconscious
        crew members, detaches them from the vehicle, and places them
        on the ground near the vehicle. Units are positioned to avoid
        stacking on top of each other.

    Params:
        0: _vehicle - OBJECT - the vehicle containing unconscious units

    Returns: nothing
*/

if (!hasInterface) exitWith {};

params ["_vehicle"];

// ======================================================================
// 1. Validate
// ======================================================================
if (isNull _vehicle) exitWith {};
if (_vehicle isEqualTo player) exitWith {};

// ======================================================================
// 2. Find all unconscious units in the vehicle
// ======================================================================
private _unconsciousCrew = [];

{
    if (_x getVariable [QGVAR(unconscious), false]) then {
        _unconsciousCrew pushBack _x;
    };
} forEach crew _vehicle;

if (count _unconsciousCrew <= 0) exitWith {
    hint "No unconscious units to unload.";
};

// ======================================================================
// 3. Unload each unconscious unit
// ======================================================================
private _vehiclePos = getPosATL _vehicle;
private _vehicleDir = getDir _vehicle;

{
    private _unit = _x;
    private _index = _forEachIndex;

    // Move out of vehicle
    moveOut _unit;

    // Detach in case they were attached
    detach _unit;

    // Calculate offset position behind the vehicle, staggered per unit
    private _offsetAngle = _vehicleDir + 180 + ((_index - (count _unconsciousCrew / 2)) * 25);
    private _offsetDist = 4 + (_index * 1.2);
    private _dropPos = _vehiclePos vectorAdd [
        _offsetDist * sin _offsetAngle,
        _offsetDist * cos _offsetAngle,
        0
    ];
    _dropPos set [2, 0];

    _unit setPosATL _dropPos;

    // Re-apply unconscious animation since moveOut clears it
    if (_unit getVariable [QGVAR(unconscious), false]) then {
        _unit playMoveNow "Acts_LyingWounded_01";
        _unit setUnconscious true;
    };

} forEach _unconsciousCrew;

hint format ["Unloaded %1 unconscious unit(s).", count _unconsciousCrew];

diag_log format ["[PRA3 Revive] Unloaded %1 unconscious units from %2.",
    count _unconsciousCrew, typeOf _vehicle];
