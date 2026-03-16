#include "script_component.hpp"
/*
    FUNC(serverSetup)

    Description:
        Server-only FOB lifecycle manager. Maintains a HashMap of active
        destruction timers keyed by deployment-point ID. Provides event
        handlers for starting, pausing, and resetting countdowns, and
        handles the actual FOB destruction sequence (explosions, deploy
        point removal, ticket penalty). Also plays ambient radio chatter
        near active FOB objects.

    Execution: server only, called once during module init.
*/

if (!isServer) exitWith {};

// ======================================================================
// 1. Timer storage
// ======================================================================
// Each key is a pointId, each value is a HashMap:
//   "startedAt"  — diag_tickTime when current run began
//   "banked"     — seconds accumulated before any pause
//   "paused"     — bool
//   "pfhId"      — per-frame handler id
//   "lastBeep"   — diag_tickTime of most recent beep
GVAR(timers) = createHashMap;

// Countdown length in seconds
GVAR(countdownLength) = 30;

// Load ticket penalty from mission config
private _cfg = missionConfigFile >> "PRA3" >> "BaseConfig";
GVAR(ticketPenalty) = getNumber (_cfg >> "ticketPenalty");
if (GVAR(ticketPenalty) <= 0) then { GVAR(ticketPenalty) = 20; };

// ======================================================================
// 2. Internal helper — create / resume the countdown PFH
// ======================================================================
DFUNC(launchCountdown) = {
    params ["_pointId"];

    private _td = GVAR(timers) getOrDefault [_pointId, createHashMap];
    if (count _td == 0) exitWith {};

    _td set ["paused", false];
    _td set ["startedAt", diag_tickTime];

    // Resolve the FOB world position from the deploy-point registry
    private _ptEntry = EGVAR(Deployment,pointStorage) getOrDefault [_pointId, createHashMap];
    private _fobPos  = _ptEntry getOrDefault ["position", [0, 0, 0]];

    private _pfhId = [{
        params ["_args", "_handle"];
        _args params ["_ptId", "_pos"];

        private _td = GVAR(timers) getOrDefault [_ptId, createHashMap];

        // Timer was removed externally — clean up
        if (count _td == 0) exitWith {
            [_handle] call PRA3_fw_removePFH;
        };

        // Skip processing while paused
        if (_td getOrDefault ["paused", false]) exitWith {};

        // Compute total elapsed seconds
        private _banked    = _td getOrDefault ["banked", 0];
        private _started   = _td getOrDefault ["startedAt", diag_tickTime];
        private _totalSec  = _banked + (diag_tickTime - _started);
        private _remaining = GVAR(countdownLength) - _totalSec;

        // --- Escalating beep sounds ---
        private _interval = if (_remaining > 20) then { 8 }
                            else { if (_remaining > 8) then { 3 } else { 0.6 } };

        private _lastBeep = _td getOrDefault ["lastBeep", 0];
        if (diag_tickTime - _lastBeep >= _interval) then {
            // Create a temporary invisible helper for the 3-D sound
            private _sndHelper = createSimpleObject ["Sign_Sphere10cm_F", _pos, true];
            _sndHelper hideObjectGlobal true;
            [_sndHelper, "beep"] remoteExecCall ["say3D", 0];
            // Remove helper after the sound finishes
            [{deleteVehicle (_this select 0)}, [_sndHelper], 2.5] call PRA3_fw_addPFH;
            _td set ["lastBeep", diag_tickTime];
        };

        // --- Timer expired — destroy the FOB ---
        if (_totalSec >= GVAR(countdownLength)) then {
            // Mortar-style explosion effects
            private _blastPos = _pos vectorAdd [0, 0, 0.4];
            createVehicle ["HelicopterExploBig",   _blastPos,                     [], 0, "CAN_COLLIDE"];
            createVehicle ["HelicopterExploSmall",  _blastPos vectorAdd [2, 3, 0], [], 0, "CAN_COLLIDE"];
            createVehicle ["HelicopterExploSmall",  _blastPos vectorAdd [-3, 1, 0],[], 0, "CAN_COLLIDE"];

            // Determine owning side before we remove the point
            private _ptData   = EGVAR(Deployment,pointStorage) getOrDefault [_ptId, createHashMap];
            private _ownSide  = _ptData getOrDefault ["availableFor", sideUnknown];

            // Remove the deployment point (deletes linked objects too)
            [_ptId] call EFUNC(Deployment,removePoint);

            // Subtract ticket penalty
            if !(_ownSide isEqualTo sideUnknown) then {
                [_ownSide, -(GVAR(ticketPenalty))] call EFUNC(Tickets,modify);
                diag_log format [
                    "[PRA3:FOB] FOB '%1' destroyed — %2 tickets from %3",
                    _ptId, GVAR(ticketPenalty), _ownSide
                ];
            };

            // Notify all machines
            ["fobDestroyed", [_ptId, _ownSide]] call PRA3_fw_fireGlobal;

            // Purge timer and PFH
            GVAR(timers) deleteAt _ptId;
            [_handle] call PRA3_fw_removePFH;
        };
    }, 0.25, [_pointId, _fobPos]] call PRA3_fw_addPFH;

    _td set ["pfhId", _pfhId];
};

// ======================================================================
// 3. Event: fobTimerStart — begin destruction countdown
// ======================================================================
["fobTimerStart", {
    params ["_pointId"];

    // Reject duplicate timers on the same FOB
    if (_pointId in GVAR(timers)) exitWith {
        diag_log format ["[PRA3:FOB] Timer already running for '%1'", _pointId];
    };

    private _td = createHashMap;
    _td set ["startedAt", diag_tickTime];
    _td set ["banked", 0];
    _td set ["paused", false];
    _td set ["lastBeep", 0];

    GVAR(timers) set [_pointId, _td];

    [_pointId] call FUNC(launchCountdown);

    // Broadcast attack warning
    ["fobUnderAttack", [_pointId]] call PRA3_fw_fireGlobal;

    diag_log format ["[PRA3:FOB] Destruction timer started for '%1'", _pointId];
}] call PRA3_fw_addHandler;

// ======================================================================
// 4. Event: fobTimerStop — pause the countdown
// ======================================================================
["fobTimerStop", {
    params ["_pointId"];

    private _td = GVAR(timers) getOrDefault [_pointId, createHashMap];
    if (count _td == 0) exitWith {};

    // Bank the elapsed time so we can resume later
    private _started = _td getOrDefault ["startedAt", diag_tickTime];
    private _prev    = _td getOrDefault ["banked", 0];
    _td set ["banked", _prev + (diag_tickTime - _started)];
    _td set ["paused", true];

    diag_log format ["[PRA3:FOB] Timer paused for '%1'", _pointId];
}] call PRA3_fw_addHandler;

// ======================================================================
// 5. Event: fobTimerReset — cancel countdown entirely
// ======================================================================
["fobTimerReset", {
    params ["_pointId"];

    private _td = GVAR(timers) getOrDefault [_pointId, createHashMap];
    if (count _td == 0) exitWith {};

    // Stop the running PFH
    private _pfh = _td getOrDefault ["pfhId", -1];
    if (_pfh >= 0) then { [_pfh] call PRA3_fw_removePFH; };

    GVAR(timers) deleteAt _pointId;

    ["fobDefused", [_pointId]] call PRA3_fw_fireGlobal;

    diag_log format ["[PRA3:FOB] Timer reset (defused) for '%1'", _pointId];
}] call PRA3_fw_addHandler;

// ======================================================================
// 6. Ambient radio chatter near active FOBs (every 45–90 s)
// ======================================================================
GVAR(nextRadioTime) = diag_tickTime + 60;

[{
    params ["_args", "_handle"];

    if (diag_tickTime < GVAR(nextRadioTime)) exitWith {};
    GVAR(nextRadioTime) = diag_tickTime + 45 + random 45;

    // Iterate every deploy point and play a radio sound at FOBs
    {
        private _entry = _y;
        if (_entry getOrDefault ["type", ""] == "FOB") then {
            private _objs = _entry getOrDefault ["objects", []];
            if (count _objs > 0) then {
                private _target = _objs select 0;
                if (!isNull _target) then {
                    [_target, "RadioAmbient"] remoteExecCall ["say3D", 0];
                };
            };
        };
    } forEach EGVAR(Deployment,pointStorage);
}, 5, []] call PRA3_fw_addPFH;

diag_log "[PRA3:FOB] Server setup finished.";
