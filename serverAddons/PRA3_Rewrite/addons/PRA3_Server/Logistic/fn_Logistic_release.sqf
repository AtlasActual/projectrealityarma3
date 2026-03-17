#include "script_component.hpp"
/*
    FUNC(release)

    Description:
        Releases/drops the object currently being carried by the player.
        Detaches it, re-enables simulation, places it on the ground,
        clears the carrying state, and resets any movement restrictions.

    Params:
        0: _unit - OBJECT - the player dropping the object

    Returns: BOOL - true if release succeeded
*/

params ["_unit"];

// Validate that we are actually carrying something
if (!GVAR(isCarrying)) exitWith {
    diag_log "[PRA3 Logistic] Release aborted — not carrying anything.";
    false
};

private _target = GVAR(carriedObject);

if (isNull _target) exitWith {
    // State desync — clean up anyway
    GVAR(isCarrying)    = false;
    GVAR(carriedObject) = objNull;
    diag_log "[PRA3 Logistic] Release aborted — carried object is null, state cleared.";
    false
};

// ======================================================================
// 1. Detach from player
// ======================================================================
detach _target;

// ======================================================================
// 2. Re-enable simulation
// ======================================================================
[_target, true] remoteExec ["enableSimulationGlobal", 2];

// ======================================================================
// 3. Place on the ground at a safe position (prevent floating)
// ======================================================================
private _unitPos = getPosATL _unit;
private _unitDir = getDir _unit;

// Drop slightly in front of the player
private _dropPos = [
    (_unitPos select 0) + (1.5 * sin _unitDir),
    (_unitPos select 1) + (1.5 * cos _unitDir),
    0
];

// Use framework safe position to avoid placing inside obstacles
private _safePos = [_dropPos, 8] call PRA3_fw_safePos;

// Force ground level — prevent floating
_target setPosATL [_safePos select 0, _safePos select 1, 0];

// Ensure correct orientation (upright)
private _currentVecUp = vectorUp _target;
if ((_currentVecUp select 2) < 0.8) then {
    _target setVectorUp [0, 0, 1];
};

// ======================================================================
// 4. Clear carrying state
// ======================================================================
GVAR(isCarrying)    = false;
GVAR(carriedObject) = objNull;

// ======================================================================
// 5. Remove speed restrictions
// ======================================================================
_unit forceWalk false;
_unit setAnimSpeedCoef 1;

// ======================================================================
// 6. Remove the GetInMan event handler
// ======================================================================
if (!isNil QGVAR(getInEHId)) then {
    _unit removeEventHandler ["GetInMan", GVAR(getInEHId)];
    GVAR(getInEHId) = nil;
};

// ======================================================================
// 7. Log and confirm
// ======================================================================
systemChat format ["Dropped %1.", typeOf _target];

diag_log format [
    "[PRA3 Logistic] %1 released %2 at %3",
    name _unit, typeOf _target, _safePos
];

true
