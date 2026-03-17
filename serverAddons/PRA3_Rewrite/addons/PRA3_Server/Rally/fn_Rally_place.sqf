#include "script_component.hpp"
/*
    FUNC(place)

    Description:
        Server-side rally-point construction guarded by the "rally" mutex.
        Validates the caller, tears down any previous rally owned by the
        group, spawns visual marker objects at the caller's position,
        registers the rally as a deployment point with limited spawn
        tickets restricted to the group, and notifies squad members.

    Parameters:
        0: _caller  — the squad leader placing the rally  (Object)

    Execution: server, inside mutex callback.
*/

params [["_caller", objNull, [objNull]]];

// ======================================================================
// 1. Validate eligibility
// ======================================================================
if (isNull _caller || {!alive _caller}) exitWith {
    diag_log "[PRA3:Rally] place — caller null or dead.";
};

if !([_caller] call FUNC(canPlace)) exitWith {
    diag_log format ["[PRA3:Rally] place — canPlace failed for %1", name _caller];
};

private _grp       = group _caller;
private _callerPos = getPosATL _caller;
private _callerDir = getDir _caller;
private _grpSide   = side _grp;

// ======================================================================
// 2. Destroy any existing rally for this group
// ======================================================================
private _prevId = _grp getVariable [QGVAR(rallyPointId), ""];
if (_prevId != "") then {
    [_prevId] call FUNC(destroy);
    diag_log format ["[PRA3:Rally] Replaced old rally '%1' for %2", _prevId, groupId _grp];
};

// ======================================================================
// 3. Spawn visual objects (tent + ground marker)
// ======================================================================
private _objs = [];

// Small field tent
private _tentPos = _callerPos;
private _tent = createSimpleObject [
    "\A3\Structures_F\Civ\Camping\TentDome_01_F.p3d",
    _tentPos,
    true
];
_tent setDir _callerDir;
_objs pushBack _tent;

// Ground marker offset to the side
private _mkrOff = [
    (_callerPos select 0) + 1.2 * sin _callerDir,
    (_callerPos select 1) + 1.2 * cos _callerDir,
    _callerPos select 2
];
private _mkr = createSimpleObject [
    "\A3\Structures_F\Mil\Helipads\HelipadEmpty_F.p3d",
    _mkrOff,
    true
];
_objs pushBack _mkr;

// ======================================================================
// 4. Read spawn ticket count
// ======================================================================
private _cfg   = missionConfigFile >> "PRA3" >> "RallyConfig";
private _tix   = getNumber (_cfg >> "spawnCount");
if (_tix <= 0) then { _tix = 9; };

// ======================================================================
// 5. Register as "RALLY" deployment point (group-restricted)
// ======================================================================
private _locName   = [_callerPos] call EFUNC(Common,nearestLocation);
private _rallyName = format ["Rally %1", groupId _grp];

private _pointId = [
    _rallyName,
    "RALLY",
    _callerPos,
    _grp,
    _tix,
    "iconRally",
    "mil_triangle",
    _objs,
    createHashMap
] call EFUNC(Deployment,addPoint);

// ======================================================================
// 6. Bookkeeping
// ======================================================================
_grp setVariable [QGVAR(rallyPointId), _pointId, true];
_grp setVariable [QGVAR(lastPlacedAt), diag_tickTime, true];

if (isNil QGVAR(liveRallies)) then { GVAR(liveRallies) = []; };
GVAR(liveRallies) pushBackUnique _pointId;

diag_log format [
    "[PRA3:Rally] '%1' placed by %2 (%3) at %4 — %5 spawns",
    _pointId, name _caller, groupId _grp, _callerPos, _tix
];

// ======================================================================
// 7. Notify the group
// ======================================================================
["rallySet", [_locName], _grp] call PRA3_fw_fireTarget;
