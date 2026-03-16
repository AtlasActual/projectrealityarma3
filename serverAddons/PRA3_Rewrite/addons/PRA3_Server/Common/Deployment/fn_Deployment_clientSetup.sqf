#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Client-side initialization for the Deployment subsystem. Sets up event
    listeners that synchronise map markers with the current deploy point
    registry. Handles point creation, removal, group switches, and ticket
    count updates.

    Arguments: none
    Returns:   nothing
*/

if !(hasInterface) exitWith {};

// Track which map markers we own, keyed by deploy point ID
GVAR(clientMarkers) = createHashMap;

// Resolve a side value to its corresponding marker color class
GVAR(markerColorForSide) = {
    params ["_targetSide"];
    switch (_targetSide) do {
        case west:          { "colorBLUFOR" };
        case east:          { "colorOPFOR" };
        case independent:   { "colorIndependent" };
        case civilian:      { "colorCivilian" };
        default             { "colorWhite" };
    };
};

// Compose marker label text, appending ticket count when finite
GVAR(formatLabel) = {
    params ["_label", "_ticketCount"];
    if (_ticketCount < 0) exitWith { _label };
    format ["%1 [%2]", _label, _ticketCount]
};

// Construct a local map marker representing a single deploy point
GVAR(spawnMarkerCreate) = {
    params ["_pid"];

    private _data = GVAR(pointStorage) getOrDefault [_pid, createHashMap];
    if (count _data == 0) exitWith {};

    private _mId       = format ["PRA3_dep_%1", _pid];
    private _mPos      = _data get "position";
    private _mLabel    = _data get "name";
    private _mTickets  = _data get "spawnTickets";
    private _mType     = _data get "mapIcon";
    private _mSide     = _data get "availableFor";

    // Clean up any stale marker with the same name
    if (_mId in allMapMarkers) then {
        deleteMarkerLocal _mId;
    };

    private _mrk = createMarkerLocal [_mId, _mPos];
    _mrk setMarkerTypeLocal _mType;
    _mrk setMarkerColorLocal ([_mSide] call GVAR(markerColorForSide));
    _mrk setMarkerTextLocal ([_mLabel, _mTickets] call GVAR(formatLabel));
    _mrk setMarkerAlphaLocal 1;

    GVAR(clientMarkers) set [_pid, _mId];
};

// Tear down the local map marker for a deploy point
GVAR(spawnMarkerDelete) = {
    params ["_pid"];

    private _mId = GVAR(clientMarkers) getOrDefault [_pid, ""];
    if (_mId isEqualTo "") exitWith {};

    deleteMarkerLocal _mId;
    GVAR(clientMarkers) deleteAt _pid;
};

// ---  Event handlers  ---

// A new deploy point appeared in the registry
["deployPointAdded", {
    params [["_pid", ""]];
    if (_pid isEqualTo "") exitWith {};

    private _data = GVAR(pointStorage) getOrDefault [_pid, createHashMap];
    if (count _data == 0) exitWith {};

    private _availFor    = _data get "availableFor";
    private _localSide   = side group player;
    private _localGroup  = group player;

    // Only display markers for points relevant to this player
    if !(_availFor isEqualTo _localSide || {_availFor isEqualTo _localGroup}) exitWith {};

    [_pid] call GVAR(spawnMarkerCreate);
}] call FWFUNC(addHandler);

// A deploy point was removed from the registry
["deployPointRemoved", {
    params [["_pid", ""]];
    if (_pid isEqualTo "") exitWith {};

    [_pid] call GVAR(spawnMarkerDelete);
}] call FWFUNC(addHandler);

// Player switched groups — rebuild all visible markers
["groupChanged", {
    // Wipe every marker we currently own
    {
        deleteMarkerLocal _y;
    } forEach GVAR(clientMarkers);
    GVAR(clientMarkers) = createHashMap;

    // Rebuild from the filtered available set
    {
        [_x] call GVAR(spawnMarkerCreate);
    } forEach (call FUNC(getAvailable));
}] call FWFUNC(addHandler);

// Spawn ticket count changed on an existing point
["ticketsChanged", {
    params [["_pid", ""]];
    if (_pid isEqualTo "") exitWith {};

    private _mId = GVAR(clientMarkers) getOrDefault [_pid, ""];
    if (_mId isEqualTo "") exitWith {};

    private _data = GVAR(pointStorage) getOrDefault [_pid, createHashMap];
    if (count _data == 0) exitWith {};

    private _label   = _data get "name";
    private _tickets = _data get "spawnTickets";
    _mId setMarkerTextLocal ([_label, _tickets] call GVAR(formatLabel));
}] call FWFUNC(addHandler);

diag_log "[PRA3] [Deployment] Client-side event listeners active";
