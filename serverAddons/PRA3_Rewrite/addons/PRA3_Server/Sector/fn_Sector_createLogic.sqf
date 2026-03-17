#include "script_component.hpp"
/*
    FUNC(createLogic)

    Description:
        Creates a logic entity representing a single sector. Stores all
        sector properties as object variables, registers the logic in
        the master lookup object, and appends it to the global list.

    Params:
        _markerName      - (String) map marker defining the sector area
        _dependencies    - (Array)  names of dependency sectors
        _ticketCost      - (Number) ticket penalty when this sector is lost
        _minTroops       - (Number) minimum attackers to begin capture
        _maxTroops       - (Number) attackers at which capture rate is maximum
        _captureDuration - (Array)  [min, max] seconds for standard capture
        _firstCapDuration- (Array)  [min, max] seconds for first-ever capture
        _label           - (String) short label for HUD / compass display

    Returns:
        Object - the created sector logic unit
*/

params [
    "_markerName",
    "_dependencies",
    "_ticketCost",
    "_minTroops",
    "_maxTroops",
    "_captureDuration",
    "_firstCapDuration",
    "_label"
];

// ======================================================================
// 1. Spawn logic unit at the marker position
// ======================================================================
private _markerPos = markerPos _markerName;
private _logicGrp = [] call PRA3_fw_getLogicGroup;
private _logic = _logicGrp createUnit ["Logic", _markerPos, [], 0, "NONE"];

// ======================================================================
// 2. Determine initial owner from marker colour
// ======================================================================
private _markerColor = markerColor _markerName;
private _ownerSide = switch (toLower _markerColor) do {
    case "colorwest";
    case "colorblue";
    case "colorblufor":     { west };
    case "coloreast";
    case "colorred";
    case "coloropfor":      { east };
    case "colorindependent";
    case "colorgreen";
    case "colorguer":       { independent };
    default                 { sideUnknown };
};

// ======================================================================
// 3. Resolve full display name
// ======================================================================
private _sectorName = _markerName;
private _fullName = markerText _markerName;
if (_fullName isEqualTo "") then {
    _fullName = _label;
};

// ======================================================================
// 4. Store all properties on the logic object
// ======================================================================
_logic setVariable [QGVAR(name),             _sectorName,      true];
_logic setVariable [QGVAR(fullName),         _fullName,         true];
_logic setVariable [QGVAR(designator),       _label,            true];
_logic setVariable [QGVAR(marker),           _markerName,       true];
_logic setVariable [QGVAR(ownerSide),        _ownerSide,        true];
_logic setVariable [QGVAR(attackingSide),    sideUnknown,       true];
_logic setVariable [QGVAR(dependencies),     _dependencies,     true];
_logic setVariable [QGVAR(ticketValue),      _ticketCost,       true];
_logic setVariable [QGVAR(minTroops),        _minTroops,        true];
_logic setVariable [QGVAR(maxTroops),        _maxTroops,        true];
_logic setVariable [QGVAR(captureDuration),  _captureDuration,  true];
_logic setVariable [QGVAR(firstCapDuration), _firstCapDuration, true];
_logic setVariable [QGVAR(everCaptured),     !(_ownerSide isEqualTo sideUnknown), true];

// Capture progress: 1.0 if initially owned, 0.0 if neutral
_logic setVariable [QGVAR(captureProgress),
    if (_ownerSide isEqualTo sideUnknown) then { 0 } else { 1 },
    true
];

// ======================================================================
// 5. Register in master lookup and global sector list
// ======================================================================
GVAR(masterObj) setVariable [_sectorName, _logic, true];
GVAR(sectorList) pushBack _logic;

diag_log format [
    "[PRA3 Sector] Created sector '%1' (%2) at %3, owner: %4",
    _sectorName, _label, _markerPos, _ownerSide
];

_logic
