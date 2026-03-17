#include "script_component.hpp"
/*
    FUNC(drawVehicle)

    Description:
        Creates or updates a local map marker for a friendly-crewed
        vehicle. Uses a vehicle-type-appropriate icon at the vehicle's
        position. Hover text shows the vehicle display name, crew count,
        and names of all crew members.

    Arguments:
        0: _vehicle  - the vehicle to draw  (Object)

    Returns: nothing
*/

params ["_vehicle"];

if (isNull _vehicle || {!alive _vehicle}) exitWith {};

private _vid     = str _vehicle;
private _pos     = getPosATL _vehicle;
private _mrkName = GVAR(vehicleIcons) getOrDefault [_vid, ""];

// Determine owning side from first living crew member
private _crewList = crew _vehicle;
private _vehSide  = sideUnknown;
{
    if (alive _x) exitWith {
        _vehSide = side group _x;
    };
} forEach _crewList;

if (_vehSide isEqualTo sideUnknown) exitWith {
    // No living crew — remove marker if it exists
    if (_mrkName isNotEqualTo "") then {
        deleteMarkerLocal _mrkName;
        GVAR(vehicleIcons) deleteAt _vid;
    };
};

// Side colour
private _color = switch (_vehSide) do {
    case west:        { "colorBLUFOR" };
    case east:        { "colorOPFOR" };
    case independent: { "colorIndependent" };
    default           { "colorCivilian" };
};

// Vehicle-type-appropriate marker icon
private _iconType = switch (true) do {
    case (_vehicle isKindOf "Helicopter"): { "mil_helicopter" };
    case (_vehicle isKindOf "Plane"):      { "mil_air" };
    case (_vehicle isKindOf "APC"):        { "mil_armor" };
    case (_vehicle isKindOf "Tank"):       { "mil_armor" };
    case (_vehicle isKindOf "Car"):        { "mil_motor_inf" };
    case (_vehicle isKindOf "Ship"):       { "mil_naval" };
    default                                { "mil_unknown" };
};

if (_mrkName isEqualTo "") then {
    _mrkName = format ["PRA3_ut_v_%1", _vid];
    private _mrk = createMarkerLocal [_mrkName, _pos];
    _mrk setMarkerTypeLocal _iconType;
    _mrk setMarkerColorLocal _color;
    _mrk setMarkerSizeLocal [0.8, 0.8];
    _mrk setMarkerAlphaLocal 0.9;

    GVAR(vehicleIcons) set [_vid, _mrkName];
} else {
    _mrkName setMarkerPosLocal _pos;
    _mrkName setMarkerTypeLocal _iconType;
    _mrkName setMarkerColorLocal _color;
};

// Hover text: vehicle name, crew count, member names
private _vehName    = getText (configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName");
private _aliveCrew  = _crewList select { alive _x };
private _crewCount  = count _aliveCrew;

private _tooltip = format ["%1 [%2/%3]", _vehName, _crewCount, getNumber (configFile >> "CfgVehicles" >> typeOf _vehicle >> "transportSoldier") + (count allTurrets _vehicle) + 1];

// Append crew names
{
    private _roleName = switch (true) do {
        case (driver _vehicle isEqualTo _x):  { "Driver" };
        case (gunner _vehicle isEqualTo _x):  { "Gunner" };
        case (commander _vehicle isEqualTo _x): { "Commander" };
        default { "Passenger" };
    };
    _tooltip = _tooltip + format [" | %1 (%2)", name _x, _roleName];
} forEach _aliveCrew;

_mrkName setMarkerTextLocal _vehName;
