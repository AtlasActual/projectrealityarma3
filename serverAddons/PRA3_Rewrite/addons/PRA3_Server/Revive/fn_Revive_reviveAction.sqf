#include "script_component.hpp"
/*
    FUNC(reviveAction)

    Description:
        Hold action on unconscious friendly units to revive them.
        Duration is reviveActionDuration, doubled if the caller lacks
        the medic trait (via reviveCoefficient). On completion, the
        target is brought out of unconsciousness: blood is restored,
        recovery animation is played, and input is re-enabled.

    Params:
        0: _caller - OBJECT - the unit performing the revive
        1: _target - OBJECT - the unconscious unit being revived

    Returns: nothing
*/

if (!hasInterface) exitWith {};

params ["_caller", "_target"];

// ======================================================================
// 1. Validate conditions
// ======================================================================
if (!alive _target) exitWith {};
if !(_target getVariable [QGVAR(unconscious), false]) exitWith {};
if (_caller distance _target > 4) exitWith {};

// ======================================================================
// 2. Calculate duration based on medic status
// ======================================================================
private _baseDuration = GVAR(reviveActionDuration);
private _isMedic = _caller getVariable [QEGVAR(Kit,isMedic), false];

private _duration = if (_isMedic) then {
    _baseDuration
} else {
    _baseDuration * GVAR(reviveCoefficient)
};

// ======================================================================
// 3. Play medic animation on caller
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

    if !(_target getVariable [QGVAR(unconscious), false]) exitWith {
        // Already revived by someone else
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
        _caller switchMove "";

        // === Revive the target ===

        // Restore blood level
        _target setVariable [QGVAR(bloodLevel), 1.0];

        // Clear unconscious state
        _target setVariable [QGVAR(unconscious), false, true];
        _target setUnconscious false;

        // Restore partial health (not full, they were downed)
        _target setDamage 0.5;

        // Play recovery animation
        _target playMoveNow "AmovPpneMstpSrasWrflDnon";

        // Re-enable input if the target is the local player
        if (_target isEqualTo player) then {
            disableUserInput false;

            // Fade out the blur effect
            if (GVAR(blurHandle) >= 0) then {
                GVAR(blurHandle) ppEffectAdjust [0];
                GVAR(blurHandle) ppEffectCommit 2.0;

                [{
                    params ["_blurHandle"];
                    _blurHandle ppEffectEnable false;
                }, 2.2, [GVAR(blurHandle)]] call PRA3_fw_waitAndExec;
            };
        };

        // Fire unconsciousness changed event
        ["unconsciousnessChanged", [_target, false]] call PRA3_fw_fireEvent;

        private _msg = format [MLOC(ReviveComplete), name _target];
        hint _msg;

        diag_log format ["[PRA3 Revive] %1 revived %2.", name _caller, name _target];
    };

}, 0.25, [_caller, _target, _startTime, _duration]] call PRA3_fw_addPFH;
