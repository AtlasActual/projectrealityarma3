#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-side 3D nametag rendering for friendly players. Draws name
        text above each friendly unit's head with distance-based scaling,
        line-of-sight checks, and a focus-time mechanic that makes names
        more visible the longer the player looks at them. Squad members
        are drawn in green, other friendlies in a dimmer blue-white.
        A microphone icon is shown when a unit is actively speaking.

    Called once per client during module init.
*/

if (!hasInterface) exitWith {};

// ======================================================================
// 1. Configuration
// ======================================================================
GVAR(maxRange)        = 100;   // metres beyond which no tags are drawn
GVAR(fadeStartRange)  = 40;    // distance at which tags begin fading
GVAR(maxUnitsProcess) = 20;    // cap on units processed per frame
GVAR(focusGainRate)   = 1.8;   // focus units per second when looking
GVAR(focusDecayRate)  = 0.6;   // focus units per second when not looking
GVAR(focusThreshold)  = 0.25;  // minimum focus before name shows

// Focus time tracking per unit: unit -> focusValue (0..1)
GVAR(focusMap) = createHashMap;

// ======================================================================
// 2. Helper: determine if camera is roughly aimed at a position
// ======================================================================
DFUNC(isLookingAt) = {
    params ["_worldPos"];
    private _screenPos = worldToScreen _worldPos;
    if (count _screenPos == 0) exitWith { false };
    _screenPos params ["_sx", "_sy"];
    // Consider "looking at" if within the central 10% of screen
    private _cx = 0.5 * safeZoneW + safeZoneX;
    private _cy = 0.5 * safeZoneH + safeZoneY;
    private _dx = abs (_sx - _cx);
    private _dy = abs (_sy - _cy);
    (_dx < safeZoneW * 0.05) && (_dy < safeZoneH * 0.08)
};

// ======================================================================
// 3. Draw3D event handler
// ======================================================================
addMissionEventHandler ["Draw3D", {
    if (isNull player) exitWith {};

    private _playerPos  = getPosATL player;
    private _playerSide = side group player;
    private _playerGrp  = group player;
    private _dt         = diag_deltaTime;
    private _processed  = 0;

    // Collect and sort candidate units by distance
    private _candidates = [];
    {
        if (_x isEqualTo player) then { continue };
        if (!alive _x) then { continue };
        if (side group _x isNotEqualTo _playerSide) then { continue };

        private _dist = _playerPos distance _x;
        if (_dist > GVAR(maxRange)) then { continue };

        _candidates pushBack [_dist, _x];
    } forEach allUnits;

    // Sort ascending by distance so nearest units are processed first
    _candidates sort true;

    {
        if (_processed >= GVAR(maxUnitsProcess)) then { break };

        _x params ["_dist", "_unit"];

        // Unit head position: use pelvis model point + vertical offset
        private _headPos = _unit modelToWorldVisual (_unit selectionPosition "pelvis");
        _headPos = _headPos vectorAdd [0, 0, 0.9];

        // Skip if behind camera (worldToScreen returns [] for off-screen)
        private _screenPos = worldToScreen _headPos;
        if (count _screenPos == 0) then { continue };

        // Line-of-sight check
        private _losBlocked = count (lineIntersectsSurfaces [
            AGLToASL (_playerPos vectorAdd [0, 0, 1.6]),
            AGLToASL _headPos,
            player, _unit,
            true, 1
        ]) > 0;

        // --- Focus time management ---
        private _unitId = str (owner _unit) + str (_unit);
        private _curFocus = GVAR(focusMap) getOrDefault [_unitId, 0];

        private _isLooking = [_headPos] call FUNC(isLookingAt);
        if (_isLooking && !_losBlocked) then {
            _curFocus = (_curFocus + _dt * GVAR(focusGainRate)) min 1;
        } else {
            _curFocus = (_curFocus - _dt * GVAR(focusDecayRate)) max 0;
        };
        GVAR(focusMap) set [_unitId, _curFocus];

        // --- Alpha computation ---
        // Distance-based fade
        private _distAlpha = if (_dist < GVAR(fadeStartRange)) then {
            1.0
        } else {
            linearConversion [GVAR(fadeStartRange), GVAR(maxRange), _dist, 1.0, 0.0, true]
        };

        // LOS penalty: reduce alpha when blocked, but don't zero it
        private _losAlpha = if (_losBlocked) then { 0.15 } else { 1.0 };

        // Focus contribution: ramp up visibility as focus increases
        private _focusAlpha = if (_curFocus < GVAR(focusThreshold)) then {
            linearConversion [0, GVAR(focusThreshold), _curFocus, 0.15, 0.5, true]
        } else {
            linearConversion [GVAR(focusThreshold), 1.0, _curFocus, 0.5, 1.0, true]
        };

        private _finalAlpha = _distAlpha * _losAlpha * _focusAlpha;
        if (_finalAlpha < 0.02) then { continue };

        // --- Colour determination ---
        private _isSquadMate = group _unit isEqualTo _playerGrp;
        private _nameColor = if (_isSquadMate) then {
            [0.3, 1.0, 0.35, _finalAlpha]
        } else {
            [0.75, 0.85, 1.0, _finalAlpha * 0.7]
        };

        // --- Text size based on distance ---
        private _textSize = linearConversion [2, GVAR(maxRange), _dist, 0.038, 0.018, true];

        // --- Draw name tag ---
        private _displayName = name _unit;
        drawIcon3D [
            "",
            _nameColor,
            _headPos,
            0, 0, 0,
            _displayName,
            2,
            _textSize,
            "PuristaMedium"
        ];

        // --- Squad role indicator (small text below name for squad mates) ---
        if (_isSquadMate) then {
            private _roleDesc = roleDescription _unit;
            if (_roleDesc isNotEqualTo "") then {
                private _rolePos = _headPos vectorAdd [0, 0, -0.2];
                drawIcon3D [
                    "",
                    [0.6, 0.9, 0.6, _finalAlpha * 0.55],
                    _rolePos,
                    0, 0, 0,
                    _roleDesc,
                    2,
                    _textSize * 0.75,
                    "PuristaMedium"
                ];
            };
        };

        // --- Microphone speaking indicator ---
        // Check via unit variable (can be set by TFAR/ACRE or custom VON handler)
        private _isSpeaking = _unit getVariable ["PRA3_isSpeaking", false];

        if (_isSpeaking) then {
            private _micPos = _headPos vectorAdd [0, 0, 0.25];
            drawIcon3D [
                "\a3\ui_f\data\IGUI\RscIngameUI\RscUnitInfo\microphone_ca.paa",
                [1, 1, 0.4, _finalAlpha * 0.9],
                _micPos,
                0.5,
                0.5,
                0,
                "",
                0
            ];
        };

        _processed = _processed + 1;
    } forEach _candidates;

    // --- Cleanup stale focus entries periodically ---
    // Every ~5 seconds, prune entries for units no longer relevant
    if (diag_tickTime mod 5 < _dt) then {
        private _toRemove = [];
        {
            if (_y <= 0) then {
                _toRemove pushBack _x;
            };
        } forEach GVAR(focusMap);
        {
            GVAR(focusMap) deleteAt _x;
        } forEach _toRemove;
    };
}];

diag_log "[PRA3 Nametags] Client nametag rendering active.";
