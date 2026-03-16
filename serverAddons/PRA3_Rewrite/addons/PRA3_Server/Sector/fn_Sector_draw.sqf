#include "script_component.hpp"
/*
    FUNC(draw)

    Description:
        Client-side rendering of a single sector on the map. Updates the
        marker colour to match the current owner, overlays ATTACK or
        DEFEND icon markers when appropriate, registers a compass marker
        via the CompassUI module, and shows the sector name as hover text.

    Params:
        _sector - (Object) the sector logic to draw

    Called from event handlers on "sideChanged" and "sectorOwnerChanged".
*/

if (!hasInterface) exitWith {};

params ["_sector"];

if (isNull _sector) exitWith {};

// ======================================================================
// 1. Read sector state
// ======================================================================
private _sectorName   = _sector getVariable [QGVAR(name), ""];
private _markerName   = _sector getVariable [QGVAR(marker), ""];
private _ownerSide    = _sector getVariable [QGVAR(ownerSide), sideUnknown];
private _attackingSide = _sector getVariable [QGVAR(attackingSide), sideUnknown];
private _designator   = _sector getVariable [QGVAR(designator), ""];
private _fullName     = _sector getVariable [QGVAR(fullName), ""];

if (_markerName isEqualTo "") exitWith {};

private _playerSide = if (!isNull player) then { side group player } else { sideUnknown };
private _sectorPos  = markerPos _markerName;

// ======================================================================
// 2. Determine colour from owner side
// ======================================================================
private _sideColor = switch (_ownerSide) do {
    case west: {
        missionNamespace getVariable [QEGVAR(Common,sideColor_west), [0, 0.3, 0.6, 0.6]]
    };
    case east: {
        missionNamespace getVariable [QEGVAR(Common,sideColor_east), [0.5, 0, 0, 0.6]]
    };
    case independent: {
        missionNamespace getVariable [QEGVAR(Common,sideColor_independent), [0, 0.5, 0, 0.6]]
    };
    default {
        [0.5, 0.5, 0.5, 0.6]
    };
};

// ======================================================================
// 3. Apply colour to the sector area marker
// ======================================================================
private _colorName = switch (_ownerSide) do {
    case west:        { "ColorBLUFOR" };
    case east:        { "ColorOPFOR" };
    case independent: { "ColorIndependent" };
    default           { "ColorUNKNOWN" };
};
_markerName setMarkerColorLocal _colorName;
_markerName setMarkerAlphaLocal 0.45;

// ======================================================================
// 4. Designator text marker
// ======================================================================
private _textMarker = format ["%1_txt", _sectorName];
if (getMarkerType _textMarker isEqualTo "") then {
    createMarkerLocal [_textMarker, _sectorPos];
    _textMarker setMarkerTypeLocal "mil_dot";
    _textMarker setMarkerSizeLocal [0, 0];
};
_textMarker setMarkerTextLocal format [" %1", _designator];
_textMarker setMarkerColorLocal _colorName;

// ======================================================================
// 5. Tactical icon overlay: ATTACK or DEFEND
// ======================================================================
private _iconMarker = format ["%1_icon", _sectorName];
deleteMarkerLocal _iconMarker;

private _canPlayerAttack = [_sector, _playerSide] call FUNC(canCapture);

if (_canPlayerAttack && {!(_ownerSide isEqualTo _playerSide)}) then {
    // ATTACK icon: sector is capturable by the player's side
    createMarkerLocal [_iconMarker, _sectorPos];
    _iconMarker setMarkerTypeLocal "mil_objective";
    _iconMarker setMarkerColorLocal "ColorBlack";
    _iconMarker setMarkerTextLocal "";
    _iconMarker setMarkerSizeLocal [0.8, 0.8];
} else {
    if (_ownerSide isEqualTo _playerSide && {!(_attackingSide isEqualTo sideUnknown)}) then {
        // DEFEND icon: player's sector is under attack
        createMarkerLocal [_iconMarker, _sectorPos];
        _iconMarker setMarkerTypeLocal "mil_warning";
        _iconMarker setMarkerColorLocal "ColorRed";
        _iconMarker setMarkerTextLocal "";
        _iconMarker setMarkerSizeLocal [0.8, 0.8];
    };
};

// ======================================================================
// 6. Compass marker via CompassUI module
// ======================================================================
private _compassColor = _sideColor select [0, 3]; // RGB only
[
    _sectorName,
    _sectorPos,
    _designator,
    _compassColor
] call EFUNC(CompassUI,addMarker);

// ======================================================================
// 7. Hover tooltip with full sector name
// ======================================================================
_markerName setMarkerTextLocal format ["%1 - %2", _designator, _fullName];
