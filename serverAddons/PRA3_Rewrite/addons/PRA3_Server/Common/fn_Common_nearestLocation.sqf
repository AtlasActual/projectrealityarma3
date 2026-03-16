#include "script_component.hpp"
/*
    PRA3_fnc_Common_nearestLocation

    Description:
        Finds the name of the nearest named location to a given position.
        Searches in order: standard named locations within 800 m, map
        markers cached during init, hill/viewpoint types at wider range,
        and finally falls back to a grid reference string.

    Parameters:
        _position - Array [x, y, z] or [x, y] : the world position to search around

    Returns:
        String - name of the nearest location, or a grid reference
*/

params [["_position", [0,0,0], [[]]]];

// --- 1. Search standard named locations within 800 m ---
private _searchTypes = [
    "NameVillage",
    "NameCity",
    "NameCityCapital",
    "NameLocal",
    "NameMarine",
    "Airport",
    "Hill",
    "ViewPoint"
];

private _nearLocs = nearestLocations [_position, _searchTypes, 800];

if (count _nearLocs > 0) exitWith {
    text (_nearLocs select 0)
};

// --- 2. Check named markers stored during init ---
private _markerMap = GVAR(markerPositions);
private _bestName = "";
private _bestDist = 1e12;

{
    private _dist = _position distance2D _y;
    if (_dist < _bestDist) then {
        _bestDist = _dist;
        _bestName = _x;
    };
} forEach _markerMap;

if (_bestName != "" && {_bestDist < 2000}) exitWith {
    _bestName
};

// --- 3. Wider search for Hill type locations (up to 5000 m) ---
private _hillLocs = nearestLocations [_position, ["Hill"], 5000];

if (count _hillLocs > 0) exitWith {
    text (_hillLocs select 0)
};

// --- 4. Fallback: grid reference ---
mapGridPosition _position
