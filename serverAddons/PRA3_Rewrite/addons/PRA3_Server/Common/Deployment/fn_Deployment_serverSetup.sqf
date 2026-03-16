#include "script_component.hpp"
/*
    FUNC(serverSetup)

    Server-side initialization for the Deployment subsystem. Iterates through
    every map marker in the mission, identifies those prefixed with "baseSpawn_",
    and registers each as a BASE-type deploy point with unlimited spawn tickets.

    Arguments: none
    Returns:   nothing
*/

if !(isServer) exitWith {};

// Translate marker color class names into engine side objects
private _sideMapping = createHashMapFromArray [
    ["colorBLUFOR",       west],
    ["colorWEST",         west],
    ["colorblue",         west],
    ["colorOPFOR",        east],
    ["colorEAST",         east],
    ["colorred",          east],
    ["colorIndependent",  independent],
    ["colorGUER",         independent],
    ["colorgreen",        independent],
    ["colorCivilian",     civilian],
    ["coloryellow",       civilian]
];

private _spawnPrefix = "baseSpawn_";
private _prefixLen = count _spawnPrefix;
private _created = 0;

{
    // Skip markers that do not begin with the expected prefix
    if !(_x find _spawnPrefix == 0) then { continue };

    private _mrkPos  = markerPos _x;
    private _mrkText = markerText _x;
    private _mrkCol  = markerColor _x;

    // Resolve side from marker color; fall back to west when unrecognised
    private _resolvedSide = _sideMapping getOrDefault [_mrkCol, west];

    // When the marker has no display text, derive a name from its identifier
    if (_mrkText isEqualTo "") then {
        _mrkText = _x select [_prefixLen];
    };

    // Register the base spawn via the standard addPoint interface
    private _id = [
        _mrkText,
        "BASE",
        _mrkPos,
        _resolvedSide,
        -1,             // unlimited tickets
        "iconBase",
        "mil_flag",
        [],
        createHashMap
    ] call FUNC(addPoint);

    diag_log format [
        "[PRA3] [Deployment] BASE '%1' registered (id: %2, pos: %3, side: %4)",
        _mrkText, _id, _mrkPos, _resolvedSide
    ];

    _created = _created + 1;
} forEach allMapMarkers;

diag_log format ["[PRA3] [Deployment] Server init finished — %1 base point(s) registered", _created];
