#include "script_component.hpp"
/*
    PRA3_fnc_fw_mutex

    Description:
        Server-routed mutex system. Clients request a lock via
        remoteExecCall to the server; the server either grants it
        immediately or queues the request. Code and args are stored
        locally on the requesting machine (code blocks cannot be
        serialized over the network). The server only manages the
        lock/unlock queue and sends grant notifications back.

    Called during framework bootstrap.
*/

// Server-side queue storage:
//   mutexName -> HashMap with keys:
//     "locked" : bool
//     "queue"  : array of [callerOwnerID]
if (isServer) then {
    GVAR(mutexQueues) = createHashMap;
};

// Client-side pending request storage:
//   requestId -> [code, args, mutexName]
GVAR(pendingRequests) = createHashMap;
GVAR(nextRequestId) = 0;

// ------------------------------------------------------------------
// PRA3_fw_mutexGranted (called on requesting machine when lock is granted)
//   Params: [requestId, mutexName]
//   Looks up the stored code/args and executes locally.
// ------------------------------------------------------------------
GVAR(mutexGranted) = {
    params ["_requestId", "_mutexName"];

    private _pending = GVAR(pendingRequests) getOrDefault [_requestId, []];
    if (count _pending == 0) exitWith {
        diag_log format ["[PRA3] Mutex grant for unknown request %1 (%2)", _requestId, _mutexName];
        [_mutexName] remoteExecCall [QGVAR(mutexRelease_srv), 2];
    };

    GVAR(pendingRequests) deleteAt _requestId;

    _pending params ["_code", "_args", "_mName"];

    // Run the critical section locally
    _args call _code;

    // Notify server to release this mutex
    [_mutexName] remoteExecCall [QGVAR(mutexRelease_srv), 2];
};

// ------------------------------------------------------------------
// Internal: server grants a lock by notifying the requesting machine
// ------------------------------------------------------------------
private _grantLock = {
    params ["_mutexName", "_requestId", "_ownerID"];

    [_requestId, _mutexName] remoteExecCall [QGVAR(mutexGranted), _ownerID];
};
GVAR(grantLock) = _grantLock;

// ------------------------------------------------------------------
// PRA3_fw_mutexLock (called on any machine)
//   Params: [mutexName, code, args, caller]
//   Stores code/args locally, sends lock request to server.
// ------------------------------------------------------------------
GVAR(mutexLock) = {
    params ["_mutexName", "_code", ["_args", []], ["_caller", if (hasInterface) then {player} else {objNull}]];

    private _ownerID = if (isNull _caller && isServer) then { 2 } else { owner _caller };

    // Store code and args locally (code blocks can't be serialized over network)
    private _requestId = format ["%1_%2", _ownerID, GVAR(nextRequestId)];
    GVAR(nextRequestId) = GVAR(nextRequestId) + 1;
    GVAR(pendingRequests) set [_requestId, [_code, _args, _mutexName]];

    // Forward request to server (only mutex name, request ID, and owner — no code)
    [_mutexName, _requestId, _ownerID] remoteExecCall [QGVAR(mutexRequest_srv), 2];
};

// ------------------------------------------------------------------
// Server-side request handler (receives forwarded lock requests)
// ------------------------------------------------------------------
GVAR(mutexRequest_srv) = {
    if (!isServer) exitWith {};

    params ["_mutexName", "_requestId", "_ownerID"];

    private _queues = GVAR(mutexQueues);

    if !(_mutexName in _queues) then {
        private _newEntry = createHashMap;
        _newEntry set ["locked", false];
        _newEntry set ["queue", []];
        _queues set [_mutexName, _newEntry];
    };
    private _entry = _queues get _mutexName;

    if !(_entry get "locked") then {
        // Mutex is free -- grant immediately
        _entry set ["locked", true];
        [_mutexName, _requestId, _ownerID] call GVAR(grantLock);
    } else {
        // Mutex is busy -- enqueue
        private _queue = _entry get "queue";
        _queue pushBack [_requestId, _ownerID];
    };
};

// ------------------------------------------------------------------
// PRA3_fw_mutexRelease_srv (server-side, called after critical section completes)
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
        _next params ["_requestId", "_ownerID"];
        [_mutexName, _requestId, _ownerID] call GVAR(grantLock);
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
