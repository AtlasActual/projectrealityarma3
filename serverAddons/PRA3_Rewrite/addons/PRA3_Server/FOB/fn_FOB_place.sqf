#include "script_component.hpp"
/*
    FUNC(place)

    Description:
        Server-side FOB construction routine guarded by the "fob" mutex.
        Validates the caller, reads the correct FOB composition from
        CfgPRA3Compositions based on the caller's side, spawns each
        composition piece as a simple object oriented relative to the
        caller, registers the FOB as a deployment point with unlimited
        spawns, and notifies the caller's side.

    Parameters:
        0: _caller  — the unit that initiated placement  (Object)

    Execution: server, inside mutex callback.
*/

params [["_caller", objNull, [objNull]]];

// ======================================================================
// 1. Validate
// ======================================================================
if (isNull _caller || {!alive _caller}) exitWith {
    diag_log "[PRA3:FOB] place — caller is null or dead, aborting.";
};

if !([_caller] call FUNC(canPlace)) exitWith {
    diag_log format ["[PRA3:FOB] place — canPlace failed for %1", name _caller];
};

private _callerSide = side group _caller;
private _callerPos  = getPosATL _caller;
private _callerDir  = getDir _caller;

// ======================================================================
// 2. Determine composition class from the side data lookup
// ======================================================================
private _sideRec    = GVAR(sideData) getOrDefault [_callerSide, createHashMap];
private _compName   = _sideRec getOrDefault ["compositionClass", ""];

// Fallback: pick a default composition name based on the side
if (_compName == "") then {
    _compName = switch (_callerSide) do {
        case west:       { "FOB_NATO" };
        case east:       { "FOB_CSAT" };
        case resistance: { "FOB_AAF" };
        default          { "FOB_NATO" };
    };
};

// ======================================================================
// 3. Read composition entries from config
// ======================================================================
private _cfgComp   = configFile >> "CfgPRA3Compositions" >> _compName;
private _pieces    = [];

if (!isNull _cfgComp) then {
    for "_i" from 0 to (count _cfgComp - 1) do {
        private _item = _cfgComp select _i;
        if (!isClass _item) then { continue };

        private _model = getText  (_item >> "model");
        private _off   = getArray (_item >> "offset");
        private _vDir  = getArray (_item >> "vectorDir");
        private _vUp   = getArray (_item >> "vectorUp");

        if (_model != "" && {count _off >= 3}) then {
            // Default orientation when config omits vectors
            if (count _vDir < 3) then { _vDir = [0, 1, 0]; };
            if (count _vUp  < 3) then { _vUp  = [0, 0, 1]; };
            _pieces pushBack [_model, _off, _vDir, _vUp];
        };
    };
};

// Hardcoded fallback if no config composition was found
if (count _pieces == 0) then {
    _pieces = [
        ["\A3\Structures_F\Mil\BagBunker\BagBunker_01_small_F.p3d",
            [0, 0, 0], [0, 1, 0], [0, 0, 1]],
        ["\A3\Structures_F\Mil\BagFence\BagFence_Long_F.p3d",
            [3, 0, 0], [0, 1, 0], [0, 0, 1]],
        ["\A3\Structures_F\Mil\BagFence\BagFence_Long_F.p3d",
            [-3, 0, 0], [0, -1, 0], [0, 0, 1]]
    ];
};

// ======================================================================
// 4. Spawn simple objects at the caller's position
// ======================================================================
private _spawnedObjs = [];
private _cosH = cos _callerDir;
private _sinH = sin _callerDir;

{
    _x params ["_model", "_off", "_vDir", "_vUp"];

    // Rotate the local offset by the caller's heading
    private _rx = (_off select 0) * _cosH - (_off select 1) * _sinH;
    private _ry = (_off select 0) * _sinH + (_off select 1) * _cosH;
    private _rz = _off select 2;

    private _worldPos = [
        (_callerPos select 0) + _rx,
        (_callerPos select 1) + _ry,
        (_callerPos select 2) + _rz
    ];

    private _obj = createSimpleObject [_model, _worldPos, true];
    _obj setVectorDirAndUp [_vDir, _vUp];

    _spawnedObjs pushBack _obj;
} forEach _pieces;

// ======================================================================
// 5. Register as a "FOB" deployment point (unlimited spawns: -1)
// ======================================================================
private _locName  = [_callerPos] call EFUNC(Common,nearestLocation);
private _fobLabel = format ["FOB %1", _locName];

private _pointId = [
    _fobLabel,
    "FOB",
    _callerPos,
    _callerSide,
    -1,
    "iconFOB",
    "mil_flag",
    _spawnedObjs,
    createHashMap
] call EFUNC(Deployment,addPoint);

diag_log format [
    "[PRA3:FOB] '%1' placed by %2 at %3 (%4 objects)",
    _pointId, name _caller, _callerPos, count _spawnedObjs
];

// ======================================================================
// 6. Notify the caller's side
// ======================================================================
private _squadName = groupId (group _caller);

["fobPlaced", [_squadName, _locName], _callerSide] call PRA3_fw_fireTarget;
