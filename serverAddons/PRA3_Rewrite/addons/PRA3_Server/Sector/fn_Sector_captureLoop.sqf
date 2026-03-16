#include "script_component.hpp"
/*
    FUNC(captureLoop)

    Description:
        Core capture mechanic. Runs as a PFH on the server for each
        contested sector. Counts alive units per side inside the sector,
        calculates a capture rate based on force ratio, and advances
        (or regresses) capture progress through neutralise and capture
        phases. Fires "sectorOwnerChanged" globally on state transitions.

    Params (via PFH args, passed as _this):
        _sector - (Object) the sector logic
        _pfhId  - (Number) PFH handle (stored in args by refreshDependencies)

    Called from FUNC(refreshDependencies) when a sector becomes active.
    The PFH args array is [_sector, _pfhId] where _pfhId is patched in
    after PFH creation.
*/

params ["_sector", "_pfhId"];

if (isNull _sector) exitWith {
    if (!isNil "_pfhId") then {
        [_pfhId] call PRA3_fw_removePFH;
    };
};

// ======================================================================
// 1. Gather alive units per side inside this sector
// ======================================================================
private _sectorName = _sector getVariable [QGVAR(name), ""];
private _tracked = GVAR(sectorUnits) getOrDefault [_sectorName, createHashMap];
private _competingSides = EGVAR(Common,competingSides);

private _sideCounts = createHashMap;
{
    private _sideUnits = _tracked getOrDefault [_x, []];
    // Purge dead or null units
    private _alive = _sideUnits select { alive _x && {!isNull _x} };
    _tracked set [_x, _alive];
    _sideCounts set [_x, count _alive];
} forEach _competingSides;

GVAR(sectorUnits) set [_sectorName, _tracked];

// ======================================================================
// 2. Determine defending and attacking sides
// ======================================================================
private _ownerSide   = _sector getVariable [QGVAR(ownerSide), sideUnknown];
private _maxTroops   = _sector getVariable [QGVAR(maxTroops), 8];
private _minTroops   = _sector getVariable [QGVAR(minTroops), 1];

private _defenderCount = _sideCounts getOrDefault [_ownerSide, 0];

// Find the strongest attacking side (any non-owner side with units)
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

// No attackers present -- nothing happens, progress does not decay
if (_bestAttackerCount < _minTroops) exitWith {};

// Update attacking side on the sector for client display
_sector setVariable [QGVAR(attackingSide), _bestAttacker, true];

// ======================================================================
// 3. Calculate capture rate
// ======================================================================
private _forceDiff = _bestAttackerCount - _defenderCount;

// Attackers must have a numerical advantage to make progress
if (_forceDiff <= 0) exitWith {};

private _progress    = _sector getVariable [QGVAR(captureProgress), 0];
private _everCaptured = _sector getVariable [QGVAR(everCaptured), false];

// Choose duration table: first capture uses shorter times
private _durArray = if (!_everCaptured && _ownerSide isEqualTo sideUnknown) then {
    _sector getVariable [QGVAR(firstCapDuration), [30, 60]];
} else {
    _sector getVariable [QGVAR(captureDuration), [60, 120]];
};

_durArray params ["_durMin", "_durMax"];

// Force ratio clamped to [0,1] based on maxTroops
private _forceRatio = ((_forceDiff / _maxTroops) max 0) min 1;

// Duration interpolates from durMax (few troops) to durMin (max troops)
private _effectiveDuration = _durMin + (_durMax - _durMin) * (1 - _forceRatio);

// Rate per second (progress moves from 0 to 1 over effectiveDuration)
private _rate = 1 / (_effectiveDuration max 0.01);

// Delta for this tick (PFH interval)
private _dt = 0.5; // This PFH runs at 0.5s intervals
private _delta = _rate * _dt;

// ======================================================================
// 4. Two-phase capture: neutralise (1 -> 0), then capture (0 -> 1)
// ======================================================================
if (_ownerSide isEqualTo sideUnknown) then {
    // --- Phase 2: capturing neutral sector ---
    private _newProgress = (_progress + _delta) min 1;
    _sector setVariable [QGVAR(captureProgress), _newProgress, true];

    if (_newProgress >= 1) then {
        // Sector captured by the attacker
        private _oldSide = sideUnknown;
        _sector setVariable [QGVAR(ownerSide), _bestAttacker, true];
        _sector setVariable [QGVAR(captureProgress), 1, true];
        _sector setVariable [QGVAR(attackingSide), sideUnknown, true];
        _sector setVariable [QGVAR(everCaptured), true, true];

        ["sectorOwnerChanged", [_sector, _oldSide, _bestAttacker]] call PRA3_fw_fireGlobal;

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
