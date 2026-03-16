#include "script_component.hpp"
/*
    FUNC(place)

    Description:
        Server-side FOB placement procedure, protected by the "respawn"
        mutex. Validates the request, reads the FOB composition from
        CfgPRA3Compositions config, spawns simple objects relative to the
        placement position, registers the FOB as a deployment point, and
        notifies all same-side players.

    Parameters:
        0: _player - the unit placing the FOB (Object)

    Returns: nothing

    Execution context: server, inside mutex callback
*/

params [["_player", objNull, [objNull]]];

// ======================================================================
// 1. Validate placement eligibility
// ======================================================================
if (isNull _player || {!alive _player}) exitWith {
    diag_log "[PRA3 FOB] place — invalid or dead player, aborting.";
};

if !([_player] call FUNC(canPlace)) exitWith {
    diag_log format ["[PRA3 FOB] place — canPlace check failed for %1", name _player];
};

private _playerSide = side group _player;
private _playerPos  = getPosATL _player;
private _playerDir  = getDir _player;

// ======================================================================
// 2. Read FOB composition from config
// ======================================================================
private _cfgComp = configFile >> "CfgPRA3Compositions" >> "FOB";
private _compItems = [];

if (!isNull _cfgComp) then {
    for "_i" from 0 to (count _cfgComp - 1) do {
        private _itemCfg = _cfgComp select _i;
        if (!isClass _itemCfg) then { continue };

        private _model   = getText  (_itemCfg >> "model");
        private _offset  = getArray (_itemCfg >> "offset");
        private _rotY    = getNumber (_itemCfg >> "rotation");

        if (_model != "" && {count _offset >= 3}) then {
            _compItems pushBack [_model, _offset, _rotY];
        };
    };
};

// Fallback: if no composition found, use a default sandbag arrangement
if (count _compItems == 0) then {
    _compItems = [
        ["\A3\Structures_F\Mil\BagBunker\BagBunker_01_small_F.p3d", [0, 0, 0], 0],
        ["\A3\Structures_F\Mil\BagFence\BagFence_Long_F.p3d",       [4, 0, 0], 0],
        ["\A3\Structures_F\Mil\BagFence\BagFence_Long_F.p3d",       [-4, 0, 0], 180],
        ["\A3\Structures_F\Mil\BagFence\BagFence_Long_F.p3d",       [0, 4, 0], 90],
        ["\A3\Structures_F\Mil\Flags\Flag_NATO_F.p3d",              [0, -2, 0], 0]
    ];
};

// ======================================================================
// 3. Spawn composition objects at player position
// ======================================================================
private _spawnedObjects = [];

{
    _x params ["_model", "_offset", "_rotY"];

    // Rotate offset by the player's heading direction
    private _cosDir = cos _playerDir;
    private _sinDir = sin _playerDir;
    private _ox = (_offset select 0) * _cosDir - (_offset select 1) * _sinDir;
    private _oy = (_offset select 0) * _sinDir + (_offset select 1) * _cosDir;
    private _oz = _offset select 2;

    private _worldPos = [
        (_playerPos select 0) + _ox,
        (_playerPos select 1) + _oy,
        (_playerPos select 2) + _oz
    ];

    private _obj = createSimpleObject [_model, _worldPos, true];
    _obj setDir (_playerDir + _rotY);

    _spawnedObjects pushBack _obj;
} forEach _compItems;

// ======================================================================
// 4. Register as a deployment point
// ======================================================================
private _locationName = [_playerPos] call EFUNC(Common,nearestLocation);

private _fobName = format ["FOB %1", _locationName];

private _pointId = [
    _fobName,
    "FOB",
    _playerPos,
    _playerSide,
    -1,
    "iconFOB",
    "mil_flag",
    _spawnedObjects,
    createHashMap
] call EFUNC(Deployment,addPoint);

diag_log format [
    "[PRA3 FOB] Placed '%1' by %2 at %3 — %4 objects spawned",
    _pointId, name _player, _playerPos, count _spawnedObjects
];

// ======================================================================
// 5. Notify all same-side players
// ======================================================================
private _squadId = group _player getVariable [QEGVAR(Squad,squadId), ""];

["fobPlaced", [_squadId, _locationName], _playerSide] call PRA3_fw_fireTarget;
