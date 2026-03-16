#include "script_component.hpp"
/*
    PRA3_fnc_fw_eventBus

    Description:
        Initializes the framework event bus system. Creates a central event
        registry and exposes functions for subscribing, unsubscribing, and
        dispatching events locally and across the network.

    Called during framework bootstrap.
*/

// Central registry: eventName -> array of [handlerCode, active]
GVAR(eventRegistry) = createHashMap;

// Counter for generating unique handler indices per event
private _idCounter = createHashMap;

// ------------------------------------------------------------------
// PRA3_fw_addHandler
//   Params: [eventName, handlerCode]
//   Optional: [eventName, handlerCode, insertFirst]
//   Returns: handler index (number)
// ------------------------------------------------------------------
GVAR(addHandler) = {
    params ["_eventName", "_handlerCode", ["_insertFirst", false]];

    private _registry = GVAR(eventRegistry);
    private _handlers = _registry getOrDefault [_eventName, []];

    if (_handlers isEqualTo []) then {
        _registry set [_eventName, _handlers];
    };

    private _idx = count _handlers;

    if (_insertFirst) then {
        _handlers insert [0, [[_handlerCode, true, _idx]]];
    } else {
        _handlers pushBack [_handlerCode, true, _idx];
    };

    _idx
};

// ------------------------------------------------------------------
// PRA3_fw_removeHandler
//   Params: [eventName, handlerIndex]
// ------------------------------------------------------------------
GVAR(removeHandler) = {
    params ["_eventName", "_handlerIndex"];

    private _handlers = GVAR(eventRegistry) getOrDefault [_eventName, []];

    {
        _x params ["_code", "_active", "_idx"];
        if (_idx isEqualTo _handlerIndex) exitWith {
            _x set [1, false];
        };
    } forEach _handlers;

    // Compact: remove all inactive entries when more than half are dead
    private _deadCount = {!(_x select 1)} count _handlers;
    if (_deadCount > (count _handlers) / 2) then {
        private _alive = _handlers select {_x select 1};
        GVAR(eventRegistry) set [_eventName, _alive];
    };
};

// ------------------------------------------------------------------
// PRA3_fw_fireEvent (local dispatch)
//   Params: [eventName, args]
// ------------------------------------------------------------------
GVAR(fireEvent) = {
    params ["_eventName", ["_args", []]];

    private _handlers = GVAR(eventRegistry) getOrDefault [_eventName, []];

    {
        _x params ["_code", "_active"];
        if (_active) then {
            _args call _code;
        };
    } forEach _handlers;
};

// ------------------------------------------------------------------
// PRA3_fw_fireGlobal (all machines)
//   Params: [eventName, args]
//   Optional: [eventName, args, jip]
//   Uses remoteExecCall so it also fires locally.
// ------------------------------------------------------------------
GVAR(fireGlobal) = {
    params ["_eventName", ["_args", []], ["_jip", false]];

    private _jipId = if (_jip) then {
        "PRA3_evt_" + _eventName
    } else {
        ""
    };

    // remoteExecCall on all machines (target 0)
    // We call PRA3_fw_fireEvent on every machine
    [[_eventName, _args], GVAR(fireEvent)] remoteExecCall ["call", 0, _jipId];
};

// ------------------------------------------------------------------
// PRA3_fw_fireServer (server only)
//   Params: [eventName, args]
// ------------------------------------------------------------------
GVAR(fireServer) = {
    params ["_eventName", ["_args", []]];

    [[_eventName, _args], GVAR(fireEvent)] remoteExecCall ["call", 2];
};

// ------------------------------------------------------------------
// PRA3_fw_fireTarget (specific targets)
//   Params: [eventName, args, targets]
//   targets can be a number (client owner ID), object, side, group,
//   or array of any of those, per remoteExecCall rules.
//   Optional: [eventName, args, targets, jip]
// ------------------------------------------------------------------
GVAR(fireTarget) = {
    params ["_eventName", ["_args", []], ["_targets", 0], ["_jip", false]];

    private _jipId = if (_jip) then {
        "PRA3_evt_" + _eventName
    } else {
        ""
    };

    [[_eventName, _args], GVAR(fireEvent)] remoteExecCall ["call", _targets, _jipId];
};

diag_log "[PRA3] Event bus initialized";
