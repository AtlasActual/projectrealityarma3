#include "script_component.hpp"
/*
    FUNC(knockOut)

    Description:
        Places a unit into the unconscious/downed state. Sets the
        unconscious variable, plays the downed animation, disables
        player input, drops weapon aim, fires the unconsciousnessChanged
        event, and starts the bleed-out loop.

    Params:
        0: _unit - OBJECT - the unit to knock out

    Returns: nothing
*/

params ["_unit"];

// Guard against double knock-out
if (_unit getVariable [QGVAR(unconscious), false]) exitWith {};

// ======================================================================
// 1. Set unconscious state
// ======================================================================
_unit setVariable [QGVAR(unconscious), true, true];
_unit setVariable [QGVAR(bloodLevel), 1.0];

// ======================================================================
// 2. Play downed animation
// ======================================================================
_unit playMoveNow "Acts_LyingWounded_01";
_unit setUnconscious true;

// ======================================================================
// 3. Disable player input (movement and firing)
// ======================================================================
if (_unit isEqualTo player) then {
    disableUserInput true;

    // Apply blur effect for unconsciousness visual
    if (GVAR(blurHandle) >= 0) then {
        GVAR(blurHandle) ppEffectEnable true;
        GVAR(blurHandle) ppEffectAdjust [6];
        GVAR(blurHandle) ppEffectCommit 1.5;
    };
};

// Safety net: if unit remains unconscious for >300s, force-kill and restore input
_unit spawn {
    private _timeout = diag_tickTime + 300;
    waitUntil {sleep 1; !alive _this || !(_this getVariable [QGVAR(unconscious), false]) || diag_tickTime > _timeout};
    if (_this getVariable [QGVAR(unconscious), false] && alive _this) then {
        _this setDamage 1;
        diag_log format ["[PRA3 Revive] Safety timeout: force-killed %1 after 300s unconscious", name _this];
    };
    if (hasInterface && _this isEqualTo player) then {
        disableUserInput false;
    };
};

// ======================================================================
// 4. Fire unconsciousness event
// ======================================================================
["unconsciousnessChanged", [_unit, true]] call PRA3_fw_fireEvent;

// ======================================================================
// 6. Start bleed-out loop
// ======================================================================
[_unit] call FUNC(bleedLoop);

diag_log format ["[PRA3 Revive] %1 knocked unconscious.", name _unit];
