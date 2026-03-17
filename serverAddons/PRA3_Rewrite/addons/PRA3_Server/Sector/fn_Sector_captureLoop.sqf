#include "script_component.hpp"
/*
    FUNC(captureLoop)

    Description:
        Core capture mechanic executed as a per-frame handler on the server
        at 0.5-second intervals for each contested sector. Counts alive
        units per side, calculates capture rate from force differential,
        and advances or decays capture progress through neutralise and
        capture phases. Fires "sectorOwnerChanged" globally on transitions.

    Params (via PFH args array, passed as _this):
        _sector - (Object) the sector logic unit
        _pfhId  - (Number) PFH handle (patched in after creation)

    Execution: server only (guarded).

    Capture model:
        - Two-phase: neutralise (progress 1.0 -> 0) then capture (0 -> 1.0)
        - Rate = 1 / (durMin + (durMax - durMin) * (1 - clamp(diff/maxTroops)))
        - Uses firstCapDuration for sectors that have never been owned
        - No passive decay: progress holds when no attackers are present
*/

if (!isServer) exitWith {};

params ["_sector", "_pfhId"];

if (isNull _sector) exitWith {
    if (!isNil "_pfhId" && {_pfhId >= 0}) then {
        [_pfhId] call PRA3_fw_removePFH;
    };
};

// ======================================================================
// 1. Count alive units per side from the tracking hashmap
// ======================================================================
private _sectorName = _sector getVariable [QGVAR(name), ""];
private _tracked = GVAR(sectorUnits) getOrDefault [_sectorName, createHashMap];
private _competingSides = EGVAR(Common,competingSides);

private _sideCounts = createHashMap;
{
    private _sideUnits = _tracked getOrDefault [_x, []];
    // Purge dead or null units in-place
    private _alive = _sideUnits select { alive _x && {!isNull _x} };
    _tracked set [_x, _alive];
    _sideCounts set [_x, count _alive];
} forEach _competingSides;
GVAR(sectorUnits) set [_sectorName, _tracked];

// ======================================================================
// 2. Read sector state
// ======================================================================
private _ownerSide  = _sector getVariable [QGVAR(ownerSide), sideUnknown];
private _maxTroops  = _sector getVariable [QGVAR(maxTroops), 8];
private _minTroops  = _sector getVariable [QGVAR(minTroops), 1];

private _defenderCount = if (_ownerSide isEqualTo sideUnknown) then {
    0
} else {
    _sideCounts getOrDefault [_ownerSide, 0]
};

// ======================================================================
// 3. Find the strongest attacking side
// ======================================================================
private _bestAttacker = sideUnknown;
private _bestAttackerCount = 0;
{
    if !(_x isEqualTo _ownerSide) then {
        private _cnt = _sideCounts getOrDefault [_x, 0];
        if (_cnt > _bestAttackerCount) then {
            _bestAttacker = _x;
            _bestAttackerCount = _cnt;
        };
    };
} forEach _competingSides;

// No attackers present or below minimum: progress does not change
if (_bestAttackerCount < _minTroops) exitWith {};

// Update attacking side for client HUD display
_sector setVariable [QGVAR(attackingSide), _bestAttacker, true];

// ======================================================================
// 4. Calculate capture rate
// ======================================================================
private _forceDiff = _bestAttackerCount - _defenderCount;

// Attackers must outnumber defenders to make progress
if (_forceDiff <= 0) exitWith {};

private _progress     = _sector getVariable [QGVAR(captureProgress), 0];
private _everCaptured = _sector getVariable [QGVAR(everCaptured), false];

// Choose duration table: first capture uses shorter times
private _durArray = if (!_everCaptured && _ownerSide isEqualTo sideUnknown) then {
    _sector getVariable [QGVAR(firstCapDuration), [30, 60]]
} else {
    _sector getVariable [QGVAR(captureDuration), [60, 120]]
};

_durArray params ["_durMin", "_durMax"];

// Force ratio clamped to [0,1]
private _forceRatio = ((_forceDiff / _maxTroops) max 0) min 1;

// Duration interpolates: durMax at minimal force, durMin at full force
private _effectiveDuration = _durMin + (_durMax - _durMin) * (1 - _forceRatio);

// Rate per second
private _rate = 1 / (_effectiveDuration max 0.01);

// Delta for this tick (PFH interval is 0.5s)
private _delta = _rate * 0.5;

// ======================================================================
// 5. Two-phase capture: neutralise (1 -> 0), then capture (0 -> 1)
// ======================================================================
if (_ownerSide isEqualTo sideUnknown) then {
    // --- Phase 2: capturing neutral sector ---
    private _newProgress = (_progress + _delta) min 1;
    _sector setVariable [QGVAR(captureProgress), _newProgress, true];

    if (_newProgress >= 1) then {
        // Sector captured
        _sector setVariable [QGVAR(ownerSide), _bestAttacker, true];
        _sector setVariable [QGVAR(captureProgress), 1, true];
        _sector setVariable [QGVAR(attackingSide), sideUnknown, true];
        _sector setVariable [QGVAR(everCaptured), true, true];

        ["sectorOwnerChanged", [_sector, sideUnknown, _bestAttacker]] call PRA3_fw_fireGlobal;

        diag_log format [
            "[PRA3 Sector] '%1' captured by %2",
            _sectorName, _bestAttacker
        ];

        // Refresh dependency graph (may start/stop other capture loops)
        [] call FUNC(refreshDependencies);
    };
} else {
    // --- Phase 1: neutralising owned sector ---
    private _newProgress = (_progress - _delta) max 0;
    _sector setVariable [QGVAR(captureProgress), _newProgress, true];

    if (_newProgress <= 0) then {
        // Sector neutralised
        private _oldSide = _ownerSide;
        _sector setVariable [QGVAR(ownerSide), sideUnknown, true];
        _sector setVariable [QGVAR(captureProgress), 0, true];

        ["sectorOwnerChanged", [_sector, _oldSide, sideUnknown]] call PRA3_fw_fireGlobal;

        diag_log format [
            "[PRA3 Sector] '%1' neutralised (was %2)",
            _sectorName, _oldSide
        ];
    };
};
