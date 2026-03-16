#include "script_component.hpp"
/*
    FUNC(serverSetup)

    Description:
        Server-only FOB management. Handles destruction countdowns with
        escalating audio cues, timer control events (start, stop,
        continue, reset), and processes completed destructions by
        spawning explosion effects, removing the deployment point, and
        applying ticket penalties. Also loops ambient radio sounds
        near active FOBs.

    Called once on the server during module init.
*/

if (!isServer) exitWith {};

// Storage for active destruction timers: pointId -> HashMap
//   "startTime"   : diag_tickTime when the timer began
//   "elapsed"     : seconds accumulated before any pause
//   "paused"      : boolean
//   "pfhId"       : per-frame handler driving the countdown
GVAR(destructionTimers) = createHashMap;

// Duration of the destruction countdown in seconds
GVAR(destroyDuration) = 30;

// ======================================================================
// Internal: start or resume the countdown PFH for a given point
// ======================================================================
DFUNC(startCountdownPFH) = {
    params ["_pointId"];

    private _timerData = GVAR(destructionTimers) getOrDefault [_pointId, createHashMap];
    if (count _timerData == 0) exitWith {};

    // Mark as running
    _timerData set ["paused", false];
    _timerData set ["startTime", diag_tickTime];

    // Retrieve the deploy point position for sound effects
    private _pointEntry = EGVAR(Deployment,pointStorage) getOrDefault [_pointId, createHashMap];
    private _fobPos = if (count _pointEntry > 0) then {
        _pointEntry get "position"
    } else {
        [0, 0, 0]
    };

    // Track the last beep time so we can control beep frequency
    private _lastBeep = diag_tickTime;

    private _pfhId = [{
        params ["_args", "_pfhId"];
        _args params ["_pointId", "_fobPos"];

        private _timerData = GVAR(destructionTimers) getOrDefault [_pointId, createHashMap];

        // Timer was removed externally
        if (count _timerData == 0) exitWith {
            [_pfhId] call PRA3_fw_removePFH;
        };

        // Timer is paused — skip processing
        if (_timerData getOrDefault ["paused", false]) exitWith {};

        private _elapsed   = _timerData getOrDefault ["elapsed", 0];
        private _startTime = _timerData getOrDefault ["startTime", diag_tickTime];
        private _running   = (diag_tickTime - _startTime) + _elapsed;

        // Determine beep interval based on time remaining
        private _remaining = GVAR(destroyDuration) - _running;
        private _beepInterval = if (_remaining > 20) then {
            10   // first phase: beep every 10 seconds
        } else {
            if (_remaining > 5) then {
                3  // middle phase: beep every 3 seconds
            } else {
                0.5  // final phase: rapid beeps
            };
        };

        // Play beep sound at the FOB position at determined intervals
        private _lastBeep = _timerData getOrDefault ["lastBeep", 0];
        if (diag_tickTime - _lastBeep >= _beepInterval) then {
            private _beepObj = createSimpleObject ["Sign_Sphere10cm_F", _fobPos, true];
            _beepObj hideObjectGlobal true;

            // Broadcast a warning tone to all machines near the FOB
            [_fobPos, "beep"] remoteExecCall ["say3D", 0];

            // Clean up the helper object after a short delay
            [{
                params ["_obj"];
                deleteVehicle _obj;
            }, 2, [_beepObj]] call PRA3_fw_waitAndExec;

            _timerData set ["lastBeep", diag_tickTime];
        };

        // Check if timer has expired
        if (_running >= GVAR(destroyDuration)) then {
            // === FOB DESTRUCTION ===

            // Visual explosion effects at the FOB position
            private _explosionPos = _fobPos vectorAdd [0, 0, 0.5];
            createVehicle ["HelicopterExploBig", _explosionPos, [], 0, "CAN_COLLIDE"];
            createVehicle ["HelicopterExploSmall", _explosionPos vectorAdd [3, 2, 0], [], 0, "CAN_COLLIDE"];

            // Retrieve the owning side before removal
            private _pointData = EGVAR(Deployment,pointStorage) getOrDefault [_pointId, createHashMap];
            private _owningSide = if (count _pointData > 0) then {
                _pointData getOrDefault ["availableFor", sideUnknown]
            } else {
                sideUnknown
            };

            // Remove the deployment point (also deletes linked objects)
            [_pointId] call EFUNC(Deployment,removePoint);

            // Subtract ticket penalty from the owning side
            if !(_owningSide isEqualTo sideUnknown) then {
                [_owningSide, -(GVAR(ticketPenalty))] call EFUNC(Tickets,modify);
                diag_log format [
                    "[PRA3 FOB] FOB '%1' destroyed — %2 tickets deducted from %3",
                    _pointId, GVAR(ticketPenalty), _owningSide
                ];
            };

            // Notify all machines
            ["fobDestroyed", [_pointId, _owningSide]] call PRA3_fw_fireGlobal;

            // Clean up the timer entry and PFH
            GVAR(destructionTimers) deleteAt _pointId;
            [_pfhId] call PRA3_fw_removePFH;
        };
    }, 0.25, [_pointId, _fobPos]] call PRA3_fw_addPFH;

    _timerData set ["pfhId", _pfhId];
};

// ======================================================================
// Event: fobDestroyStart — enemy initiates destruction countdown
// ======================================================================
["fobDestroyStart", {
    params ["_pointId"];

    // Prevent duplicate timers on the same FOB
    if (_pointId in GVAR(destructionTimers)) exitWith {
        diag_log format ["[PRA3 FOB] Destruction timer already active for '%1'", _pointId];
    };

    private _timerData = createHashMap;
    _timerData set ["startTime", diag_tickTime];
    _timerData set ["elapsed", 0];
    _timerData set ["paused", false];
    _timerData set ["lastBeep", 0];

    GVAR(destructionTimers) set [_pointId, _timerData];

    // Start the countdown PFH
    [_pointId] call FUNC(startCountdownPFH);

    // Notify all players about the attack
    ["fobUnderAttack", [_pointId]] call PRA3_fw_fireGlobal;

    diag_log format ["[PRA3 FOB] Destruction countdown started for '%1'", _pointId];
}] call PRA3_fw_addHandler;

// ======================================================================
// Event: fobDestroyStop — pause the destruction countdown
// ======================================================================
["fobDestroyStop", {
    params ["_pointId"];

    private _timerData = GVAR(destructionTimers) getOrDefault [_pointId, createHashMap];
    if (count _timerData == 0) exitWith {};

    // Record how much time has elapsed so far
    private _startTime = _timerData getOrDefault ["startTime", diag_tickTime];
    private _prevElapsed = _timerData getOrDefault ["elapsed", 0];
    _timerData set ["elapsed", _prevElapsed + (diag_tickTime - _startTime)];
    _timerData set ["paused", true];

    diag_log format ["[PRA3 FOB] Destruction timer paused for '%1'", _pointId];
}] call PRA3_fw_addHandler;

// ======================================================================
// Event: fobTimerStart — explicitly begin a fresh countdown
// ======================================================================
["fobTimerStart", {
    params ["_pointId"];

    // Behaves the same as fobDestroyStart
    ["fobDestroyStart", [_pointId]] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

// ======================================================================
// Event: fobTimerStop — explicitly pause the countdown
// ======================================================================
["fobTimerStop", {
    params ["_pointId"];

    ["fobDestroyStop", [_pointId]] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

// ======================================================================
// Event: fobTimerContinue — resume a paused countdown
// ======================================================================
["fobTimerContinue", {
    params ["_pointId"];

    private _timerData = GVAR(destructionTimers) getOrDefault [_pointId, createHashMap];
    if (count _timerData == 0) exitWith {};

    if (_timerData getOrDefault ["paused", false]) then {
        [_pointId] call FUNC(startCountdownPFH);
        diag_log format ["[PRA3 FOB] Destruction timer resumed for '%1'", _pointId];
    };
}] call PRA3_fw_addHandler;

// ======================================================================
// Event: fobTimerReset — cancel the destruction countdown entirely
// ======================================================================
["fobTimerReset", {
    params ["_pointId"];

    private _timerData = GVAR(destructionTimers) getOrDefault [_pointId, createHashMap];
    if (count _timerData == 0) exitWith {};

    // Stop the PFH
    private _pfhId = _timerData getOrDefault ["pfhId", -1];
    if (_pfhId >= 0) then {
        [_pfhId] call PRA3_fw_removePFH;
    };

    // Purge the timer record
    GVAR(destructionTimers) deleteAt _pointId;

    // Notify all machines that the FOB has been defused
    ["fobDefused", [_pointId]] call PRA3_fw_fireGlobal;

    diag_log format ["[PRA3 FOB] Destruction timer reset (defused) for '%1'", _pointId];
}] call PRA3_fw_addHandler;

// ======================================================================
// Event: fobDismantle — friendly removal of own FOB
// ======================================================================
["fobDismantle", {
    params ["_pointId"];

    // If there is an active destruction timer, clear it first
    private _timerData = GVAR(destructionTimers) getOrDefault [_pointId, createHashMap];
    if (count _timerData > 0) then {
        private _pfhId = _timerData getOrDefault ["pfhId", -1];
        if (_pfhId >= 0) then {
            [_pfhId] call PRA3_fw_removePFH;
        };
        GVAR(destructionTimers) deleteAt _pointId;
    };

    // Remove the deployment point
    [_pointId] call EFUNC(Deployment,removePoint);

    diag_log format ["[PRA3 FOB] FOB '%1' dismantled by squad leader", _pointId];
}] call PRA3_fw_addHandler;

// ======================================================================
// Load ticket penalty setting from config (server side)
// ======================================================================
private _cfgFOB = missionConfigFile >> "PRA3" >> "cfgFOB";
GVAR(ticketPenalty) = getNumber (_cfgFOB >> "ticketPenalty");
if (GVAR(ticketPenalty) <= 0) then { GVAR(ticketPenalty) = 20; };

diag_log "[PRA3 FOB] Server setup complete.";
