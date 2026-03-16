#include "script_component.hpp"
/*
    FUNC(drawUnit)

    Description:
        Creates or updates a local map marker for a single friendly unit.
        The icon is coloured by the unit's side. On hover the unit name is
        displayed. If the unit is unconscious (revive system), a red cross
        revive indicator is shown instead of the normal icon.

    Arguments:
        0: _unit  - the unit to draw on the map  (Object)

    Returns: nothing
*/

params ["_unit"];

if (isNull _unit || {!alive _unit}) exitWith {};

private _uid      = str _unit;
private _pos      = getPosATL _unit;
private _unitSide = side group _unit;
private _mrkName  = GVAR(unitIcons) getOrDefault [_uid, ""];

// Determine icon colour from side
private _color = switch (_unitSide) do {
    case west:        { "colorBLUFOR" };
    case east:        { "colorOPFOR" };
    case independent: { "colorIndependent" };
    default           { "colorCivilian" };
};

// Check if unit is unconscious (needs revive indicator)
private _isUnconscious = _unit getVariable [QEGVAR(Revive,unconscious), false];

// Icon type: revive cross for unconscious, small dot for normal
private _iconType = if (_isUnconscious) then {
    "mil_warning"
} else {
    "mil_dot"
};

// Marker color override for unconscious units
private _drawColor = if (_isUnconscious) then {
    "colorRed"
} else {
    _color
};

if (_mrkName isEqualTo "") then {
    // Create new marker
    _mrkName = format ["PRA3_ut_u_%1", _uid];
    private _mrk = createMarkerLocal [_mrkName, _pos];
    _mrk setMarkerTypeLocal _iconType;
    _mrk setMarkerColorLocal _drawColor;
    _mrk setMarkerSizeLocal [0.6, 0.6];
    _mrk setMarkerTextLocal "";
    _mrk setMarkerAlphaLocal 0.85;

    GVAR(unitIcons) set [_uid, _mrkName];
} else {
    // Update existing marker
    _mrkName setMarkerPosLocal _pos;
    _mrkName setMarkerTypeLocal _iconType;
    _mrkName setMarkerColorLocal _drawColor;
};

// Hover text: show unit name (set as marker text so it appears on hover)
private _hoverText = name _unit;
if (_isUnconscious) then {
    _hoverText = format ["%1 (DOWN)", _hoverText];
};
_mrkName setMarkerTextLocal _hoverText;
