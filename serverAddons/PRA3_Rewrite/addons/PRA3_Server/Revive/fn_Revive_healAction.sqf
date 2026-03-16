#include "script_component.hpp"
/*
    FUNC(healAction)

    Description:
        Hold action on friendly damaged units to heal them. Duration
        is healActionDuration, doubled if the caller does not have the
        medic trait (via healCoefficient). On completion, the target's
        damage is set to zero.

    Params:
        0: _caller - OBJECT - the unit performing the heal
        1: _target - OBJECT - the unit being healed

    Returns: nothing
*/

params ["_caller", "_target"];

// ======================================================================
// 1. Validate conditions
// ======================================================================
if (!alive _target) exitWith {};
if (_target getVariable [QGVAR(unconscious), false]) exitWith {};
if (damage _target <= 0) exitWith {};
if (_caller distance _target > 4) exitWith {};

// ======================================================================
// 2. Calculate duration based on medic status
// ======================================================================
private _baseDuration = GVAR(healActionDuration);
private _isMedic = _caller getVariable [QEGVAR(Kit,isMedic), false];

private _duration = if (_isMedic) then {
    _baseDuration
} else {
    _baseDuration * GVAR(healCoefficient)
};

// ======================================================================
// 3. Play healing animation on caller
// ======================================================================
_caller playMove "AinvPknlMstpSnonWnonDnon_medic1";

// ======================================================================
// 4. Progress-based hold action loop
// ======================================================================
private _startTime = time;

[{
    params ["_args", "_pfhId"];
    _args params ["_caller", "_target", "_startTime", "_duration"];

    // Abort conditions
    if (!alive _caller || {!alive _target}) exitWith {
        _pfhId call PRA3_fw_removePFH;
        _caller switchMove "";
    };

    if (_target getVariable [QGVAR(unconscious), false]) exitWith {
        _pfhId call PRA3_fw_removePFH;
        _caller switchMove "";
    };

    if (_caller distance _target > 5) exitWith {
        _pfhId call PRA3_fw_removePFH;
        _caller switchMove "";
        hint "Too far from patient.";
    };

    // Check progress
    private _elapsed = time - _startTime;
    private _progress = _elapsed / _duration;

    if (_progress >= 1.0) exitWith {
        _pfhId call PRA3_fw_removePFH;

        // Heal the target
        _target setDamage 0;
        _caller switchMove "";

        private _msg = format [MLOC(HealComplete), name _target];
        hint _msg;

        diag_log format ["[PRA3 Revive] %1 healed %2.", name _caller, name _target];
    };

}, 0.25, [_caller, _target, _startTime, _duration]] call PRA3_fw_addPFH;
