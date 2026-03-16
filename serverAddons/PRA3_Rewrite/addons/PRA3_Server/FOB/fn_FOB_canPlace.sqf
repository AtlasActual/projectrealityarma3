#include "script_component.hpp"
/*
    FUNC(canPlace)

    Description:
        Evaluates whether a unit satisfies every prerequisite for placing
        a FOB at their current position.

    Checks:
        - unit is the group leader
        - unit is on foot (not in a vehicle)
        - no friendly FOB exists within minDistance (600 m)
        - no more than maxEnemyToPlace (5) enemies within 50 m

    Parameters:
        0: _unit  — the player requesting placement  (Object)

    Returns:
        Boolean
*/

params [["_unit", objNull, [objNull]]];

// Basic validity
if (isNull _unit || {!alive _unit}) exitWith { false };

// Must be the squad leader
if (_unit != leader group _unit) exitWith { false };

// Must be dismounted
if (vehicle _unit != _unit) exitWith { false };

private _uSide = side group _unit;
private _uPos  = getPosATL _unit;

// ======================================================================
// Minimum distance from existing friendly FOBs
// ======================================================================
private _minDist = GVAR(minDistance);
if (_minDist <= 0) then { _minDist = 600; };

private _tooClose = false;
{
    private _rec = _y;
    if (_rec getOrDefault ["type", ""] == "FOB") then {
        if ((_rec getOrDefault ["availableFor", sideUnknown]) isEqualTo _uSide) then {
            private _fPos = _rec getOrDefault ["position", [0, 0, 0]];
            if (_uPos distance2D _fPos < _minDist) exitWith {
                _tooClose = true;
            };
        };
    };
} forEach EGVAR(Deployment,pointStorage);

if (_tooClose) exitWith { false };

// ======================================================================
// Maximum enemy presence within 50 m
// ======================================================================
private _maxEnemy = GVAR(maxEnemyToPlace);
if (_maxEnemy <= 0) then { _maxEnemy = 5; };

private _nearby     = [_uPos, 50] call PRA3_fw_getNearUnits;
private _enemyCount = 0;

{
    if !(side group _x isEqualTo _uSide) then {
        _enemyCount = _enemyCount + 1;
    };
} forEach _nearby;

if (_enemyCount > _maxEnemy) exitWith { false };

// All checks passed
true
