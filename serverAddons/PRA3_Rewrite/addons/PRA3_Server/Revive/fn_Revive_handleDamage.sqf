#include "script_component.hpp"
/*
    FUNC(handleDamage)

    Description:
        HandleDamage event handler replacement. Intercepts lethal damage
        to redirect the unit into an unconscious state instead of killing
        them outright, when preventInstantDeath is enabled.

    Params (standard HandleDamage EH):
        0: _unit       - OBJECT
        1: _selection  - STRING
        2: _damage     - NUMBER
        3: _source     - OBJECT
        4: _projectile - STRING
        5: _hitIndex   - NUMBER
        6: _instigator - OBJECT
        7: _hitPoint   - STRING

    Returns:
        NUMBER - the damage value to apply
*/

params ["_unit", "_selection", "_damage", "_source", "_projectile", "_hitIndex", "_instigator", "_hitPoint"];

// Only process for the local player
if (_unit isNotEqualTo player) exitWith { _damage };

// ======================================================================
// 1. If already unconscious, absorb all incoming damage
// ======================================================================
if (_unit getVariable [QGVAR(unconscious), false]) exitWith {
    // Return current damage level to prevent further harm
    if (_selection isEqualTo "") then {
        damage _unit
    } else {
        _unit getHitIndex _hitIndex
    };
};

// ======================================================================
// 2. Check if this damage would be lethal
// ======================================================================
private _currentDamage = if (_selection isEqualTo "") then {
    damage _unit
} else {
    _unit getHitIndex _hitIndex
};

// Trigger blood screen effect proportional to incoming damage
private _incomingDelta = _damage - _currentDamage;
if (_incomingDelta > 0.05) then {
    [_incomingDelta min 1.0] call FUNC(bloodScreen);
};

// Check lethality: overall damage exceeds 1.0 threshold
private _wouldKill = false;
if (_selection isEqualTo "") then {
    if (_damage >= 1.0) then {
        _wouldKill = true;
    };
} else {
    // Structural hit that would cause death
    if (_damage >= 1.0) then {
        _wouldKill = true;
    };
};

// ======================================================================
// 3. Redirect lethal damage to unconscious state
// ======================================================================
if (_wouldKill && {GVAR(preventInstantDeath) > 0}) exitWith {
    // Knock the unit out instead of killing
    [_unit] call FUNC(knockOut);

    // Return sub-lethal damage so the engine does not kill the unit
    0.9
};

// ======================================================================
// 4. Normal damage passthrough
// ======================================================================
_damage
