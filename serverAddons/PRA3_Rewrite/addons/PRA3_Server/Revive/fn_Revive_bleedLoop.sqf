#include "script_component.hpp"
/*
    FUNC(bleedLoop)

    Description:
        Per-frame handler that runs while a unit is unconscious. Drains
        the blood level over time at a rate of 1/unconsciousDuration per
        second. When blood reaches zero, the unit dies. The PFH is
        removed upon death or revive.

    Params:
        0: _unit - OBJECT - the unconscious unit

    Returns: nothing
*/

params ["_unit"];

// Store the start time for blood calculation
_unit setVariable [QGVAR(bleedStartTime), time];

// Blood drain rate: fraction lost per second
private _drainRate = 1.0 / GVAR(unconsciousDuration);

[{
    params ["_args", "_pfhId"];
    _args params ["_unit", "_drainRate"];

    // ======================================================================
    // 1. Check termination conditions
    // ======================================================================
    // Unit is dead
    if (!alive _unit) exitWith {
        _pfhId call PRA3_fw_removePFH;
    };

    // Unit is no longer unconscious (was revived)
    if !(_unit getVariable [QGVAR(unconscious), false]) exitWith {
        _pfhId call PRA3_fw_removePFH;
    };

    // ======================================================================
    // 2. Drain blood level
    // ======================================================================
    private _startTime = _unit getVariable [QGVAR(bleedStartTime), time];
    private _elapsed = time - _startTime;
    private _bloodLevel = 1.0 - (_elapsed * _drainRate);
    _bloodLevel = _bloodLevel max 0.0;

    _unit setVariable [QGVAR(bloodLevel), _bloodLevel];

    // ======================================================================
    // 3. Kill unit when blood is depleted
    // ======================================================================
    if (_bloodLevel <= 0) exitWith {
        _pfhId call PRA3_fw_removePFH;

        // Ensure unconscious state is cleared before death
        _unit setVariable [QGVAR(unconscious), false, true];

        if (_unit isEqualTo player) then {
            disableUserInput false;

            if (GVAR(blurHandle) >= 0) then {
                GVAR(blurHandle) ppEffectEnable false;
            };
        };

        _unit setDamage 1;

        diag_log format ["[PRA3 Revive] %1 bled out.", name _unit];
    };

}, 0.5, [_unit, _drainRate]] call PRA3_fw_addPFH;
