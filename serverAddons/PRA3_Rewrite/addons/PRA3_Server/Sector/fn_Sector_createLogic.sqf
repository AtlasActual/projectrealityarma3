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
        _ticketValue     - (Number) ticket cost when this sector changes hands
        _minUnits        - (Number) minimum attackers to begin capture
        _maxUnits        - (Number) attackers at which capture rate is maximum
        _captureTime     - (Array)  [min, max] seconds for standard capture
        _firstCaptureTime- (Array)  [min, max] seconds for first-ever capture
        _designator      - (String) short label for HUD / compass display

    Returns:
        Object - the created sector logic unit
*/

params [
    "_markerName",
    "_dependencies",
    "_ticketValue",
    "_minUnits",
    "_maxUnits",
    "_captureTime",
    "_firstCaptureTime",
    "_designator"
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
// 3. Resolve full name from config or marker text
// ======================================================================
private _sectorName = _markerName;
private _fullName = "";

// Try to get a display name from the mission config
private _cfgRoot = missionConfigFile >> "PRA3" >> "CfgSectors";
{
    private _pathCfg = _cfgRoot select _forEachIndex;
    if (isClass _pathCfg) then {
        for "_i" from 0 to (count _pathCfg - 1) do {
            private _entry = _pathCfg select _i;
            if (isClass _entry) then {
                private _mk = getText (_entry >> "marker");
                if (_mk isEqualTo "" ) then { _mk = configName _entry };
                if (_mk isEqualTo _markerName) exitWith {
                    _fullName = getText (_entry >> "name");
                };
            };
        };
    };
} forEach (configProperties [_cfgRoot, "isClass _x", true]);

if (_fullName isEqualTo "") then {
    _fullName = markerText _markerName;
};
if (_fullName isEqualTo "") then {
    _fullName = _designator;
};

// ======================================================================
// 4. Store all properties on the logic object
// ======================================================================
_logic setVariable [QGVAR(name),              _sectorName,       true];
_logic setVariable [QGVAR(fullName),          _fullName,          true];
_logic setVariable [QGVAR(designator),        _designator,        true];
_logic setVariable [QGVAR(marker),            _markerName,        true];
_logic setVariable [QGVAR(ownerSide),         _ownerSide,         true];
_logic setVariable [QGVAR(attackingSide),     sideUnknown,        true];
_logic setVariable [QGVAR(dependencies),      _dependencies,      true];
_logic setVariable [QGVAR(ticketValue),       _ticketValue,       true];
_logic setVariable [QGVAR(minUnits),          _minUnits,          true];
_logic setVariable [QGVAR(maxUnits),          _maxUnits,          true];
_logic setVariable [QGVAR(captureTime),       _captureTime,       true];
_logic setVariable [QGVAR(firstCaptureTime),  _firstCaptureTime,  true];
_logic setVariable [QGVAR(isActive),          false,              true];
_logic setVariable [QGVAR(pfhId),             -1,                 true];

// Capture progress: 1.0 if initially owned, 0 if neutral
_logic setVariable [QGVAR(captureProgress),
    if (_ownerSide isEqualTo sideUnknown) then { 0 } else { 1 },
    true
];

// ======================================================================
// 5. Register in master lookup and global sector list
// ======================================================================
GVAR(masterLogic) setVariable [_sectorName, _logic, true];
GVAR(allSectorsList) pushBack _logic;

diag_log format [
    "[PRA3 Sector] Created sector '%1' (%2) at %3, owner: %4",
    _sectorName, _designator, _markerPos, _ownerSide
];

_logic
