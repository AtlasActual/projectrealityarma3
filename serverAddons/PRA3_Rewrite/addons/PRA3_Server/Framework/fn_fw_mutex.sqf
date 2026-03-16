#include "script_component.hpp"
/*
    PRA3_fnc_fw_mutex

    Description:
        Server-routed mutex system. Clients request a lock via
        remoteExecCall to the server; the server either grants it
        immediately or queues the request. After the client finishes
        its critical section it calls mutexRelease back on the server,
        which processes the next queued request.

    Called during framework bootstrap.
*/

// Server-side queue storage:
//   mutexName -> HashMap with keys:
//     "locked" : bool
//     "queue"  : array of [code, args, callerOwnerID]
if (isServer) then {
    GVAR(mutexQueues) = createHashMap;
};

// ------------------------------------------------------------------
// Internal: server grants a lock by executing code on the caller
// ------------------------------------------------------------------
private _grantLock = {
    params ["_mutexName", "_code", "_args", "_ownerID"];

    // Execute the critical section on the requesting machine
    // After it completes, the code itself triggers a release
    [
        [_mutexName, _code, _args],
        {
            params ["_mutexName", "_code", "_args"];

            // Run the critical section
            _args call _code;

            // Notify server to release this mutex
            [_mutexName] remoteExecCall [QGVAR(mutexRelease_srv), 2];
        }
    ] remoteExecCall ["call", _ownerID];
};
GVAR(grantLock) = _grantLock;

// ------------------------------------------------------------------
// PRA3_fw_mutexLock (called on any machine, forwarded to server)
//   Params: [mutexName, code, args, caller]
//   caller is the player object whose machine will run the code
// ------------------------------------------------------------------
GVAR(mutexLock) = {
    params ["_mutexName", "_code", ["_args", []], ["_caller", player]];

    private _ownerID = owner _caller;

    // Forward request to server
    [
        [_mutexName, _code, _args, _ownerID],
        GVAR(mutexRequest_srv)
    ] remoteExecCall ["call", 2];
};

// ------------------------------------------------------------------
// Server-side request handler (receives forwarded lock requests)
// ------------------------------------------------------------------
GVAR(mutexRequest_srv) = {
    if (!isServer) exitWith {};

    params ["_mutexName", "_code", "_args", "_ownerID"];

    private _queues = GVAR(mutexQueues);
    private _entry = _queues getOrDefault [_mutexName, createHashMap];

    if !(_queues getOrDefault [_mutexName, false] isEqualType createHashMap) then {
        _entry = createHashMap;
        _entry set ["locked", false];
        _entry set ["queue", []];
        _queues set [_mutexName, _entry];
    };

    // First-time setup for this mutex name
    if !("locked" in _entry) then {
        _entry set ["locked", false];
        _entry set ["queue", []];
        _queues set [_mutexName, _entry];
    };

    if !(_entry get "locked") then {
        // Mutex is free -- grant immediately
        _entry set ["locked", true];
        [_mutexName, _code, _args, _ownerID] call GVAR(grantLock);
    } else {
        // Mutex is busy -- enqueue
        private _queue = _entry get "queue";
        _queue pushBack [_code, _args, _ownerID];
    };
};

// ------------------------------------------------------------------
// PRA3_fw_mutexRelease (server-side, called by client after completion)
//   Params: [mutexName]
// ------------------------------------------------------------------
GVAR(mutexRelease_srv) = {
    if (!isServer) exitWith {};

    params ["_mutexName"];

    private _queues = GVAR(mutexQueues);
    private _entry = _queues getOrDefault [_mutexName, createHashMap];

    if !("queue" in _entry) exitWith {
        diag_log format ["[PRA3] Mutex release for unknown mutex '%1'", _mutexName];
    };

    private _queue = _entry get "queue";

    if (count _queue > 0) then {
        // Dequeue next waiting request and grant it
        private _next = _queue deleteAt 0;
        _next params ["_code", "_args", "_ownerID"];
        [_mutexName, _code, _args, _ownerID] call GVAR(grantLock);
    } else {
        // No one waiting, mark as free
        _entry set ["locked", false];
    };
};

// ------------------------------------------------------------------
// PRA3_fw_mutexRelease (public client-callable convenience wrapper)
//   Params: [mutexName]
//   Sends release notification to the server.
// ------------------------------------------------------------------
GVAR(mutexRelease) = {
    params ["_mutexName"];

    [_mutexName] remoteExecCall [QGVAR(mutexRelease_srv), 2];
};

diag_log "[PRA3] Mutex system initialized";
