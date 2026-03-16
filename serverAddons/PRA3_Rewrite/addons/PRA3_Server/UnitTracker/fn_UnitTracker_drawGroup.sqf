#include "script_component.hpp"
/*
    FUNC(drawGroup)

    Description:
        Creates or updates a local map marker representing a friendly
        group at its leader's position. The marker uses the group's side
        colour. On hover, a tooltip is generated showing the squad
        designation, group type, description, and a member list with
        role descriptions as kit indicators.

    Arguments:
        0: _group  - the group to draw  (Group)

    Returns: nothing
*/

params ["_group"];

if (isNull _group) exitWith {};

private _leader = leader _group;
if (isNull _leader || {!alive _leader}) exitWith {};

private _gid     = str _group;
private _pos     = getPosATL _leader;
private _grpSide = side _group;
private _mrkName = GVAR(groupIcons) getOrDefault [_gid, ""];

// Colour by side
private _color = switch (_grpSide) do {
    case west:        { "colorBLUFOR" };
    case east:        { "colorOPFOR" };
    case independent: { "colorIndependent" };
    default           { "colorCivilian" };
};

// Group identifier text
private _groupId = groupId _group;

if (_mrkName isEqualTo "") then {
    // Create new group marker
    _mrkName = format ["PRA3_ut_g_%1", _gid];
    private _mrk = createMarkerLocal [_mrkName, _pos];
    _mrk setMarkerTypeLocal "mil_marker";
    _mrk setMarkerColorLocal _color;
    _mrk setMarkerSizeLocal [0.7, 0.7];
    _mrk setMarkerAlphaLocal 0.9;

    GVAR(groupIcons) set [_gid, _mrkName];
} else {
    _mrkName setMarkerPosLocal _pos;
    _mrkName setMarkerColorLocal _color;
};

// Build tooltip string for hover display
// Format: "ALPHA | Infantry | 4 members\n- Name (Rifleman)\n- Name (Medic)..."
private _members    = units _group;
private _aliveCount = { alive _x } count _members;
private _desc       = _group getVariable [QGVAR(description), ""];
private _grpType    = _group getVariable [QGVAR(type), "Infantry"];

private _tooltip = format ["%1 | %2", _groupId, _grpType];
if (_desc isNotEqualTo "") then {
    _tooltip = _tooltip + " | " + _desc;
};
_tooltip = _tooltip + format [" (%1)", _aliveCount];

// Append member list
{
    if (!alive _x) then { continue };
    private _memberName = name _x;
    private _memberRole = roleDescription _x;
    if (_memberRole isEqualTo "") then {
        _memberRole = "Soldier";
    };
    _tooltip = _tooltip + format [" | %1 [%2]", _memberName, _memberRole];
} forEach _members;

_mrkName setMarkerTextLocal _groupId;
