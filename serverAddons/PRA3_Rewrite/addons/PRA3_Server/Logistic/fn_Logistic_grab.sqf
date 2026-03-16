#include "script_component.hpp"
/*
    FUNC(grab)

    Description:
        Grabs/drags a target object and attaches it to the player.
        Checks weight limits, ejects gunners from static weapons,
        applies walk animation for heavy objects, and disables
        the target's simulation to prevent physics issues.

    Params:
        0: _unit   - OBJECT - the player performing the grab
        1: _target - OBJECT - the object being grabbed

    Returns: BOOL - true if grab succeeded
*/

params ["_unit", "_target"];

// Validate inputs
if (isNull _unit || {isNull _target}) exitWith {
    diag_log "[PRA3 Logistic] Grab aborted — null unit or target.";
    false
};

// Prevent grabbing if already carrying
if (GVAR(isCarrying)) exitWith {
    systemChat "You are already carrying an object.";
    false
};

// Prevent grabbing objects attached to someone else
if (!isNull (attachedTo _target)) exitWith {
    systemChat "That object is already being carried.";
    false
};

// ======================================================================
// 1. Calculate weight and enforce limits
// ======================================================================
private _weight = [_target] call FUNC(calcWeight);
private _maxWeight = 800;

if (_weight > _maxWeight) exitWith {
    private _excess = _weight - _maxWeight;
    systemChat format ["Too heavy! Exceeds limit by %1 units (%2 / %3).", round _excess, round _weight, _maxWeight];

    // Fire notification event for UI feedback
    ["logisticNotify", ["TooHeavy", format ["%1 excess", round _excess]]] call PRA3_fw_fireEvent;

    false
};

// ======================================================================
// 2. Handle static weapons — eject gunner if occupied
// ======================================================================
if (_target isKindOf "StaticWeapon") then {
    private _gunner = gunner _target;
    if (!isNull _gunner) then {
        _gunner action ["Eject", _target];
        // Brief delay for ejection to complete
        [{
            params ["_g"];
            if (vehicle _g == _g) exitWith {};
            _g action ["Eject", vehicle _g];
        }, 0.5, [_gunner]] call PRA3_fw_addPFH;
    };
};

// ======================================================================
// 3. Attach object to the player
// ======================================================================
// Determine attachment offset based on object size
private _boundingBox = boundingBoxReal _target;
private _objHeight = ((_boundingBox select 1) select 2) - ((_boundingBox select 0) select 2);
private _attachOffset = [0, 1.2, _objHeight * 0.5 + 0.1];

_target attachTo [_unit, _attachOffset];

// ======================================================================
// 4. Disable target simulation to prevent physics glitches
// ======================================================================
_target enableSimulationGlobal false;

// ======================================================================
// 5. Force walk animation if the object is heavy
// ======================================================================
private _heavyThreshold = 400;

if (_weight > _heavyThreshold) then {
    _unit forceWalk true;
    _unit setAnimSpeedCoef 0.7;

    diag_log format [
        "[PRA3 Logistic] Heavy load (%1) — walk enforced on %2",
        round _weight, name _unit
    ];
} else {
    // Moderate encumbrance for lighter objects
    _unit setAnimSpeedCoef 0.85;
};

// ======================================================================
// 6. Update carrying state
// ======================================================================
GVAR(isCarrying)    = true;
GVAR(carriedObject) = _target;

// ======================================================================
// 7. Add GetInMan EH to auto-drop when entering a vehicle
// ======================================================================
GVAR(getInEHId) = _unit addEventHandler ["GetInMan", {
    params ["_unit", "_role", "_vehicle", "_turret"];

    if (GVAR(isCarrying)) then {
        [_unit] call FUNC(release);
        systemChat "Dropped carried object to enter vehicle.";
    };
}];

// ======================================================================
// 8. Log and confirm
// ======================================================================
systemChat format ["Grabbed %1 (weight: %2).", typeOf _target, round _weight];

diag_log format [
    "[PRA3 Logistic] %1 grabbed %2 (weight: %3)",
    name _unit, typeOf _target, round _weight
];

true
