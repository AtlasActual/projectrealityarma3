#include "macros.hpp"
/*
    Project Reality ArmA 3

    Author: BadGuy, joko // Jonas

    Description:
    Create Sector Trigger

    Parameter(s):
    0: Argument Name <Object, String>

    Returns:
    None
*/

params ["_sector"];

if (_sector isEqualType "") then {
    _sector = [_sector] call FUNC(getSector);
};
private _marker = _sector getVariable ["marker",""];
private _size = getMarkerSize _marker;

if (isServer) then {
    {
        private _trig = createTrigger ["EmptyDetector", getMarkerPos _marker,false];
        _trig setTriggerArea [_size select 0, _size select 1, markerDir _marker, (markerShape _marker) == "RECTANGLE"];
        _trig setTriggerActivation [_x, "PRESENT", true];
        //_trig setTriggerStatements ["this","hint 'Entered'", "hint 'Leaved'"];
        _sector setVariable [format["trigger_%1",_x], _trig];
        nil;
    } count EGVAR(Mission,competingSides);
};

if (hasInterface) then {
    private _trig = _sector getVariable ["trigger",objNull];
    if (isNull _trig) then {
        _trig = createTrigger ["EmptyDetector", getMarkerPos _marker, false];
        _trig setTriggerArea [_size select 0, _size select 1, markerDir _marker, (markerShape _marker) == "RECTANGLE"];
        _trig setTriggerActivation ["ANY", "PRESENT", true];
        _trig setTriggerStatements ["this && {PRA3_Player in thisList}", format ["['sector_entered','%1'] call PRA3_Core_fnc_localEvent;",_marker], format ["['sector_leaved','%1'] call PRA3_Core_fnc_localEvent;",_marker]];
        _sector setVariable ["trigger",_trig];
    };
    _trig triggerAttachVehicle [PRA3_Player];
};
