#include "script_component.hpp"
/*
    FUNC(canPlace)

    Description:
        Determines whether a unit is allowed to place a squad rally point.

    Checks:
        - Unit is group leader
        - Unit is on foot
        - Group's cooldown timer has expired
        - No enemies within enemyCheckRadius (50 m)
        - At least nearPlayerCount (1) other squad members within 10 m

    Parameters:
        0: _unit  — the player requesting placement  (Object)

    Returns:
        Boolean
*/

params [["_unit", objNull, [objNull]]];

if (isNull _unit || {!alive _unit}) exitWith { false };

// Must lead the squad
if (_unit != leader group _unit) exitWith { false };

// Must be dismounted
if (vehicle _unit != _unit) exitWith { false };

private _grp  = group _unit;
private _uPos = getPosATL _unit;
private _uSide = side _grp;

// ======================================================================
// Cooldown
// ======================================================================
private _cd = if (isNil QGVAR(cooldownTime)) then { 300 } else { GVAR(cooldownTime) };
if (_cd <= 0) then { _cd = 300; };

private _lastSet  = _grp getVariable [QGVAR(lastPlacedAt), 0];
if (diag_tickTime - _lastSet < _cd) exitWith { false };

// ======================================================================
// Enemy proximity — no enemies within configured radius
// ======================================================================
private _eRadius = if (isNil QGVAR(enemyCheckRadius)) then { 50 } else { GVAR(enemyCheckRadius) };
if (_eRadius <= 0) then { _eRadius = 50; };

private _scan       = [_uPos, _eRadius] call PRA3_fw_getNearUnits;
private _hasHostile = false;

{
    if (side group _x isNotEqualTo _uSide && {side group _x isNotEqualTo civilian}) exitWith {
        _hasHostile = true;
    };
} forEach _scan;

if (_hasHostile) exitWith { false };

// ======================================================================
// Nearby squad members — at least nearPlayerCount within 10 m
// ======================================================================
private _minNear = if (isNil QGVAR(nearPlayerCount)) then { 1 } else { GVAR(nearPlayerCount) };
if (_minNear <= 0) then { _minNear = 1; };

private _closeFriends = 0;
{
    if (_x != _unit && {alive _x} && {_uPos distance2D getPosATL _x <= 10}) then {
        _closeFriends = _closeFriends + 1;
    };
} forEach units _grp;

if (_closeFriends < _minNear) exitWith { false };

// All requirements met
true
