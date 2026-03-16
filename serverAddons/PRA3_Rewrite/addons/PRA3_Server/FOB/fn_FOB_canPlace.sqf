#include "script_component.hpp"
/*
    FUNC(canPlace)

    Description:
        Validates whether a given player is permitted to place a FOB at
        their current position. Checks squad leadership, on-foot status,
        minimum distance from friendly FOBs, and maximum nearby enemy
        presence.

    Parameters:
        0: _player - the unit requesting FOB placement (Object)

    Returns:
        Boolean - true when all placement requirements are satisfied
*/

params [["_player", objNull, [objNull]]];

// Must be a valid, alive player
if (isNull _player || {!alive _player}) exitWith { false };

// Must be the group leader
if (_player != leader group _player) exitWith { false };

// Must be on foot (not inside any vehicle)
if (vehicle _player != _player) exitWith { false };

private _playerSide = side group _player;
private _playerPos  = getPosATL _player;

// ======================================================================
// Check minimum distance from all existing friendly FOBs
// ======================================================================
private _minDist = GVAR(minDistance);
if (_minDist <= 0) then { _minDist = 400; };

private _allPoints = EGVAR(Deployment,pointStorage);
private _tooClose  = false;

{
    private _entry = _y;
    private _type  = _entry getOrDefault ["type", ""];
    private _avail = _entry getOrDefault ["availableFor", sideUnknown];

    if (_type == "FOB" && {_avail isEqualTo _playerSide}) then {
        private _fobPos = _entry getOrDefault ["position", [0, 0, 0]];
        if (_playerPos distance2D _fobPos < _minDist) exitWith {
            _tooClose = true;
        };
    };
} forEach _allPoints;

if (_tooClose) exitWith { false };

// ======================================================================
// Check enemy count within maxEnemyDistance
// ======================================================================
private _enemyDist  = GVAR(maxEnemyDistance);
private _enemyLimit = GVAR(maxEnemyCount);

if (_enemyDist <= 0)  then { _enemyDist  = 100; };
if (_enemyLimit <= 0) then { _enemyLimit = 2;   };

private _nearUnits  = [_playerPos, _enemyDist] call PRA3_fw_getNearUnits;
private _enemyCount = 0;

{
    if !(side group _x isEqualTo _playerSide) then {
        _enemyCount = _enemyCount + 1;
    };
} forEach _nearUnits;

if (_enemyCount >= _enemyLimit) exitWith { false };

// All checks passed
true
