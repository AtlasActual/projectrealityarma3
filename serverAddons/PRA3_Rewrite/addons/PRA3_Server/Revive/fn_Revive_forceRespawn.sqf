#include "script_component.hpp"
/*
    FUNC(forceRespawn)

    Description:
        Self-action available while the player is unconscious. After a
        1.5-second hold, kills the unit (setDamage 1) to trigger the
        respawn cycle. Clears unconscious state and re-enables input
        before death so the respawn screen can appear cleanly.

    Params:
        0: _unit - OBJECT - the unconscious player unit

    Returns: nothing
*/

params ["_unit"];

// ======================================================================
// 1. Validate: only works while unconscious
// ======================================================================
if !(_unit getVariable [QGVAR(unconscious), false]) exitWith {};
if (_unit isNotEqualTo player) exitWith {};

// ======================================================================
// 2. Hold timer (1.5 seconds)
// ======================================================================
private _startTime = time;
private _holdDuration = 1.5;

[{
    params ["_args", "_pfhId"];
    _args params ["_unit", "_startTime", "_holdDuration"];

    // Cancel if no longer unconscious (someone revived us)
    if !(_unit getVariable [QGVAR(unconscious), false]) exitWith {
        _pfhId call PRA3_fw_removePFH;
    };

    private _elapsed = time - _startTime;

    if (_elapsed >= _holdDuration) exitWith {
        _pfhId call PRA3_fw_removePFH;

        // Clear unconscious state cleanly before death
        _unit setVariable [QGVAR(unconscious), false, true];
        _unit setUnconscious false;

        // Re-enable input so respawn screen works
        disableUserInput false;

        // Remove blur
        if (GVAR(blurHandle) >= 0) then {
            GVAR(blurHandle) ppEffectEnable false;
        };

        // Kill the unit to trigger respawn
        _unit setDamage 1;

        diag_log format ["[PRA3 Revive] %1 forced respawn.", name _unit];
    };

}, 0.1, [_unit, _startTime, _holdDuration]] call PRA3_fw_addPFH;
