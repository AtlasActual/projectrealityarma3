#include "script_component.hpp"
/*
    FUNC(draw)

    Description:
        Client-side rendering of a single sector on the map. Updates the
        marker colour to match the current owner, overlays ATTACK or
        DEFEND icon markers when appropriate, registers a compass marker
        for active sectors, and shows designator + full name on hover.

    Params:
        _sector - (Object) the sector logic unit to draw
*/

if (!hasInterface) exitWith {};

params ["_sector"];

if (isNull _sector) exitWith {};

// ======================================================================
// 1. Read sector state
// ======================================================================
private _sectorName    = _sector getVariable [QGVAR(name), ""];
private _markerName    = _sector getVariable [QGVAR(marker), ""];
private _ownerSide     = _sector getVariable [QGVAR(ownerSide), sideUnknown];
private _attackingSide  = _sector getVariable [QGVAR(attackingSide), sideUnknown];
private _isActive      = _sector getVariable [QGVAR(isActive), false];
private _designator    = _sector getVariable [QGVAR(designator), ""];
private _fullName      = _sector getVariable [QGVAR(fullName), ""];
private _dependencies  = _sector getVariable [QGVAR(dependencies), []];

if (_markerName isEqualTo "") exitWith {};

private _playerSide = if (!isNull player) then { side group player } else { sideUnknown };
private _sectorPos = markerPos _markerName;

// ======================================================================
// 2. Get owner side colour from Common module variables
// ======================================================================
private _sideColor = switch (_ownerSide) do {
    case west: {
        missionNamespace getVariable [QEGVAR(Common,sideColor_west), [0, 0.3, 0.6, 0.8]]
    };
    case east: {
        missionNamespace getVariable [QEGVAR(Common,sideColor_east), [0.5, 0, 0, 0.8]]
    };
    case independent: {
        missionNamespace getVariable [QEGVAR(Common,sideColor_independent), [0, 0.5, 0, 0.8]]
    };
    default {
        [0.5, 0.5, 0.5, 0.8]
    };
};

// ======================================================================
// 3. Apply colour to the sector area marker
// ======================================================================
private _colorName = switch (_ownerSide) do {
    case west:        { "ColorBLUFOR" };
    case east:        { "ColorOPFOR" };
    case independent: { "ColorIndependent" };
    default           { "ColorWhite" };
};
_markerName setMarkerColorLocal _colorName;

// Dim inactive sectors
private _alpha = if (_isActive) then { 1.0 } else { 0.45 };
_markerName setMarkerAlphaLocal _alpha;

// ======================================================================
// 4. Tactical icon overlay: ATTACK or DEFEND
// ======================================================================
private _iconMarker = format ["%1_icon", _sectorName];
deleteMarkerLocal _iconMarker;

private _ownedByPlayer = _ownerSide isEqualTo _playerSide;

// Check if sector is capturable by the player's side
private _capturableByPlayer = false;
if (!_ownedByPlayer && _isActive) then {
    if (_dependencies isEqualTo []) then {
        _capturableByPlayer = true;
    } else {
        {
            private _depSector = [_x] call FUNC(get);
            if (!isNull _depSector) then {
                private _depOwner = _depSector getVariable [QGVAR(ownerSide), sideUnknown];
                if (_depOwner isEqualTo _playerSide) exitWith {
                    _capturableByPlayer = true;
                };
            };
        } forEach _dependencies;
    };
};

if (_capturableByPlayer) then {
    // ATTACK icon: sector can be captured by player's side
    private _mk = createMarkerLocal [_iconMarker, _sectorPos];
    _mk setMarkerTypeLocal "mil_destroy";
    _mk setMarkerColorLocal "ColorRed";
    _mk setMarkerTextLocal format ["ATK %1", _designator];
    _mk setMarkerSizeLocal [0.7, 0.7];
} else {
    if (_ownedByPlayer && {!(_attackingSide isEqualTo sideUnknown)}) then {
        // DEFEND icon: player's sector is under attack
        private _mk = createMarkerLocal [_iconMarker, _sectorPos];
        _mk setMarkerTypeLocal "mil_flag";
        _mk setMarkerColorLocal "ColorBlue";
        _mk setMarkerTextLocal format ["DEF %1", _designator];
        _mk setMarkerSizeLocal [0.7, 0.7];
    };
};

// ======================================================================
// 5. Compass line marker for active sectors
// ======================================================================
if (_isActive) then {
    private _compassColor = if (_ownedByPlayer) then {
        if !(_attackingSide isEqualTo sideUnknown) then {
            [1, 0.5, 0, 1]       // Orange: under attack
        } else {
            _sideColor            // Own colour: secure
        };
    } else {
        if (_capturableByPlayer) then {
            [1, 0, 0, 1]         // Red: attack target
        } else {
            [0.6, 0.6, 0.6, 0.4] // Grey: not reachable
        };
    };

    [
        _sectorName,
        _sectorPos,
        _designator,
        _compassColor
    ] call EFUNC(CompassUI,addMarker);
};

// ======================================================================
// 6. Hover tooltip: designator and full name
// ======================================================================
_markerName setMarkerTextLocal format ["%1 - %2", _designator, _fullName];
