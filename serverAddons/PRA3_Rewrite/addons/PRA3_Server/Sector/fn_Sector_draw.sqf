#include "script_component.hpp"
/*
    FUNC(draw)

    Description:
        Client-side drawing function for a single sector. Configures the
        sector's map marker colour based on ownership, adds tactical
        ATTACK / DEFEND icon markers, updates compass markers via the
        CompassUI module, and prepares hover text.

    Params:
        _sector - (Object) the sector logic to draw

    Called from event handlers on "sideChanged" and "sectorOwnerChanged".
*/

params ["_sector"];

if (isNull _sector) exitWith {};
if (!hasInterface) exitWith {};

private _sectorName  = _sector getVariable [QGVAR(name), ""];
private _markerName  = _sector getVariable [QGVAR(marker), ""];
private _ownerSide   = _sector getVariable [QGVAR(ownerSide), sideUnknown];
private _designator  = _sector getVariable [QGVAR(designator), ""];
private _fullName    = _sector getVariable [QGVAR(fullName), ""];
private _dependencies = _sector getVariable [QGVAR(dependencies), []];

if (_markerName isEqualTo "") exitWith {};

// ======================================================================
// 1. Determine colour based on owner side
// ======================================================================
private _color = switch (_ownerSide) do {
    case west:        { EGVAR(Common,sideColor_west) };
    case east:        { EGVAR(Common,sideColor_east) };
    case independent: { EGVAR(Common,sideColor_independent) };
    default {
        // Neutral / unknown -- use a grey tone
        [0.5, 0.5, 0.5, 0.6]
    };
};

// Fallback if side colour variable is not defined
if (isNil "_color") then {
    _color = switch (_ownerSide) do {
        case west:        { [0, 0.3, 0.6, 0.6] };
        case east:        { [0.5, 0, 0, 0.6] };
        case independent: { [0, 0.5, 0, 0.6] };
        default           { [0.5, 0.5, 0.5, 0.6] };
    };
};

// ======================================================================
// 2. Update the area marker colour and text
// ======================================================================
_markerName setMarkerColorLocal "Default";
_markerName setMarkerAlphaLocal 0.45;

// Apply custom RGBA via setMarkerColor (uses colour name or config)
private _colorName = switch (_ownerSide) do {
    case west:        { "ColorBLUFOR" };
    case east:        { "ColorOPFOR" };
    case independent: { "ColorIndependent" };
    default           { "ColorUNKNOWN" };
};
_markerName setMarkerColorLocal _colorName;

// ======================================================================
// 3. Designator text marker (create once, update position)
// ======================================================================
private _textMarker = format ["%1_txt", _sectorName];
if (getMarkerType _textMarker isEqualTo "") then {
    createMarkerLocal [_textMarker, markerPos _markerName];
    _textMarker setMarkerTypeLocal "mil_dot";
    _textMarker setMarkerSizeLocal [0, 0];
};
_textMarker setMarkerTextLocal format [" %1", _designator];
_textMarker setMarkerColorLocal _colorName;

// ======================================================================
// 4. Tactical icon: ATTACK if capturable by player, DEFEND if threatened
// ======================================================================
private _playerSide = if (!isNull player) then { side group player } else { sideUnknown };
private _iconMarker = format ["%1_icon", _sectorName];

// Remove old icon
deleteMarkerLocal _iconMarker;

private _canPlayerAttack = [_sector, _playerSide] call FUNC(canCapture);
private _attackingSide = _sector getVariable [QGVAR(attackingSide), sideUnknown];

if (_canPlayerAttack && {!(_ownerSide isEqualTo _playerSide)}) then {
    // Show ATTACK icon
    createMarkerLocal [_iconMarker, markerPos _markerName];
    _iconMarker setMarkerTypeLocal "mil_objective";
    _iconMarker setMarkerColorLocal "ColorBlack";
    _iconMarker setMarkerTextLocal "";
    _iconMarker setMarkerSizeLocal [0.8, 0.8];
} else {
    if (_ownerSide isEqualTo _playerSide && {!(_attackingSide isEqualTo sideUnknown)}) then {
        // Show DEFEND icon
        createMarkerLocal [_iconMarker, markerPos _markerName];
        _iconMarker setMarkerTypeLocal "mil_warning";
        _iconMarker setMarkerColorLocal "ColorRed";
        _iconMarker setMarkerTextLocal "";
        _iconMarker setMarkerSizeLocal [0.8, 0.8];
    };
};

// ======================================================================
// 5. Compass marker via CompassUI module
// ======================================================================
private _compassColor = _color select [0, 3]; // RGB only
[
    _sectorName,
    markerPos _markerName,
    _designator,
    _compassColor
] call EFUNC(CompassUI,addMarker);
