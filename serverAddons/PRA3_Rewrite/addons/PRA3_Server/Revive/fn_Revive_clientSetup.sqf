#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-side revive system initialization. Reads config values,
        registers the HandleDamage EH, sets up 3D medic icon drawing,
        configures hold actions for heal/revive/drag/unload/forceRespawn,
        and prepares unconsciousness screen effects.

    Called from the framework client bootstrap.
*/

if (!hasInterface) exitWith {};

// ======================================================================
// 1. Read revive configuration from mission config
// ======================================================================
private _reviveCfg = missionConfigFile >> "PRA3" >> "Revive";

GVAR(unconsciousDuration)  = getNumber (_reviveCfg >> "unconsciousDuration");
GVAR(healActionDuration)   = getNumber (_reviveCfg >> "healActionDuration");
GVAR(reviveActionDuration) = getNumber (_reviveCfg >> "reviveActionDuration");
GVAR(healCoefficient)      = getNumber (_reviveCfg >> "healCoefficient");
GVAR(reviveCoefficient)    = getNumber (_reviveCfg >> "reviveCoefficient");
GVAR(preventInstantDeath)  = getNumber (_reviveCfg >> "preventInstantDeath");

// Apply sensible defaults where config is missing
if (GVAR(unconsciousDuration) <= 0)  then { GVAR(unconsciousDuration)  = 300; };
if (GVAR(healActionDuration) <= 0)   then { GVAR(healActionDuration)   = 8; };
if (GVAR(reviveActionDuration) <= 0) then { GVAR(reviveActionDuration) = 12; };
if (GVAR(healCoefficient) <= 0)      then { GVAR(healCoefficient)      = 2.0; };
if (GVAR(reviveCoefficient) <= 0)    then { GVAR(reviveCoefficient)    = 2.0; };
if (isNil {GVAR(preventInstantDeath)}) then { GVAR(preventInstantDeath) = 1; };

// State tracking
GVAR(isDragging) = false;
GVAR(dragTarget) = objNull;
GVAR(blurHandle) = -1;

// ======================================================================
// 2. HandleDamage event handler
// ======================================================================
private _damageEHId = player addEventHandler ["HandleDamage", {
    _this call FUNC(handleDamage)
}];

player setVariable [QGVAR(damageEHId), _damageEHId];

// ======================================================================
// 3. Respawn handler: reset state and re-add HandleDamage EH
// ======================================================================
["playerRespawned", {
    params ["_unit", "_corpse"];

    _unit setVariable [QGVAR(unconscious), false, true];
    _unit setVariable [QGVAR(bloodLevel), 1.0];

    // Remove stale EH from previous life if lingering
    private _oldEHId = _unit getVariable [QGVAR(damageEHId), -1];
    if (_oldEHId >= 0) then {
        _unit removeEventHandler ["HandleDamage", _oldEHId];
    };

    // Fresh HandleDamage EH
    private _newEHId = _unit addEventHandler ["HandleDamage", {
        _this call FUNC(handleDamage)
    }];
    _unit setVariable [QGVAR(damageEHId), _newEHId];

    // Clean up blur effect if still active
    if (GVAR(blurHandle) >= 0) then {
        ppEffectDestroy GVAR(blurHandle);
        GVAR(blurHandle) = -1;
    };

    // Re-enable input in case it was locked
    disableUserInput false;

}] call PRA3_fw_addHandler;

// ======================================================================
// 4. 3D medic icon drawing for unconscious friendlies
// ======================================================================
addMissionEventHandler ["Draw3D", {
    if (isNull player) exitWith {};

    private _playerPos = getPosATL player;
    private _playerSide = side group player;

    {
        if (!alive _x) then { continue };
        if (side group _x isNotEqualTo _playerSide) then { continue };
        if !(_x getVariable [QGVAR(unconscious), false]) then { continue };
        if (_x isEqualTo player) then { continue };

        private _targetPos = getPosATL _x;
        private _dist = _playerPos distance _targetPos;

        // Only draw within 200m
        if (_dist > 200) then { continue };

        // Line-of-sight check
        if !(lineIntersectsSurfaces [
            AGLToASL (_targetPos vectorAdd [0, 0, 1.5]),
            AGLToASL (_playerPos vectorAdd [0, 0, 1.5]),
            _x, player
        ] isEqualTo []) then { continue };

        // Calculate alpha: full within 25m, fade linearly to 200m
        private _alpha = 1.0;
        if (_dist > 25) then {
            _alpha = linearConversion [25, 200, _dist, 1.0, 0.0, true];
        };

        // Animated pulse effect for the icon (subtle scale oscillation)
        private _pulse = 1.0 + 0.15 * sin (time * 360);
        private _iconSize = 0.6 * _pulse;

        private _drawPos = _targetPos vectorAdd [0, 0, 1.8];

        drawIcon3D [
            "\a3\ui_f\data\IGUI\Cfg\Actions\heal_ca.paa",
            [1, 0.2, 0.2, _alpha],
            _drawPos,
            _iconSize,
            _iconSize,
            0,
            "",
            2,
            0.03,
            "PuristaMedium"
        ];

        // Distance text below the icon
        if (_dist > 5) then {
            drawIcon3D [
                "",
                [1, 1, 1, _alpha * 0.7],
                _drawPos vectorAdd [0, 0, -0.3],
                0, 0, 0,
                format ["%1m", round _dist],
                2,
                0.025,
                "PuristaMedium"
            ];
        };
    } forEach allUnits;
}];

// ======================================================================
// 5. Hold actions setup
// ======================================================================

// --- Heal action on damaged friendlies ---
player addAction [
    MLOC(HealAction),
    { [player, cursorObject] call FUNC(healAction) },
    nil, 6, true, true, "",
    "alive cursorObject
     && {cursorObject isNotEqualTo player}
     && {side group cursorObject isEqualTo side group player}
     && {damage cursorObject > 0}
     && {!(cursorObject getVariable ['PRA3_Revive_unconscious', false])}
     && {player distance cursorObject < 3}"
];

// --- Revive action on unconscious friendlies ---
player addAction [
    MLOC(ReviveAction),
    { [player, cursorObject] call FUNC(reviveAction) },
    nil, 7, true, true, "",
    "alive cursorObject
     && {cursorObject isNotEqualTo player}
     && {side group cursorObject isEqualTo side group player}
     && {cursorObject getVariable ['PRA3_Revive_unconscious', false]}
     && {player distance cursorObject < 3}"
];

// --- Drag action on unconscious friendlies ---
player addAction [
    MLOC(DragAction),
    { [player, cursorObject] call FUNC(dragAction) },
    nil, 5, true, true, "",
    "alive cursorObject
     && {cursorObject isNotEqualTo player}
     && {side group cursorObject isEqualTo side group player}
     && {cursorObject getVariable ['PRA3_Revive_unconscious', false]}
     && {!(player getVariable ['PRA3_Revive_isDragging', false])}
     && {player distance cursorObject < 3}"
];

// --- Force respawn (self-action while unconscious) ---
player addAction [
    MLOC(ForceRespawnAction),
    { [player] call FUNC(forceRespawn) },
    nil, 1, false, true, "",
    "player getVariable ['PRA3_Revive_unconscious', false]"
];

// --- Unload unconscious from vehicle ---
player addAction [
    MLOC(UnloadAction),
    { [vehicle player] call FUNC(unloadAction) },
    nil, 4, true, true, "",
    "vehicle player isNotEqualTo player
     && {driver vehicle player isEqualTo player || gunner vehicle player isEqualTo player}
     && {{_x getVariable ['PRA3_Revive_unconscious', false]} count crew vehicle player > 0}"
];

// ======================================================================
// 6. Unconsciousness blur post-processing setup
// ======================================================================
GVAR(blurHandle) = ppEffectCreate ["DynamicBlur", 502];
GVAR(blurHandle) ppEffectEnable false;

diag_log "[PRA3 Revive] Client setup complete.";
