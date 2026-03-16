#include "script_component.hpp"
/*
    PRA3_fnc_fw_stateMachine

    Description:
        Minimal state machine implementation backed by HashMaps.
        Each state machine is a HashMap containing its state table,
        current state, arguments, and an optional per-frame handler ID
        that drives transitions.

    Called during framework bootstrap.
*/

// ------------------------------------------------------------------
// PRA3_fw_createSM
//   Returns: a new state machine HashMap
// ------------------------------------------------------------------
GVAR(createSM) = {
    private _sm = createHashMap;
    _sm set ["states", createHashMap];
    _sm set ["current", ""];
    _sm set ["args", []];
    _sm set ["pfhId", -1];
    _sm
};

// ------------------------------------------------------------------
// PRA3_fw_addState
//   Params: [sm, stateName, stateCode]
//   stateCode receives [args, stateName, sm] and must return either
//   a nextState string or [nextState, newArgs].
// ------------------------------------------------------------------
GVAR(addState) = {
    params ["_sm", "_stateName", "_stateCode"];

    private _states = _sm get "states";
    _states set [_stateName, _stateCode];
};

// ------------------------------------------------------------------
// PRA3_fw_startSM
//   Params: [sm, initialState, interval]
//   interval is in seconds (0 = every frame). Starts a PFH that
//   evaluates the current state each tick.
// ------------------------------------------------------------------
GVAR(startSM) = {
    params ["_sm", "_initialState", ["_interval", 0]];

    _sm set ["current", _initialState];

    private _pfhId = [
        {
            params ["_smRef"];

            private _curState = _smRef get "current";
            if (_curState isEqualTo "") exitWith {};

            private _states = _smRef get "states";
            private _stateCode = _states getOrDefault [_curState, {}];

            if (_stateCode isEqualTo {}) exitWith {
                diag_log format ["[PRA3] SM warning: state '%1' has no handler", _curState];
            };

            private _smArgs = _smRef get "args";
            private _result = [_smArgs, _curState, _smRef] call _stateCode;

            // Interpret result: string or [string, args]
            if (_result isEqualType "") then {
                if (_result isNotEqualTo _curState) then {
                    _smRef set ["current", _result];
                };
            } else {
                if (_result isEqualType []) then {
                    _result params [["_nextState", _curState], ["_nextArgs", _smArgs]];
                    _smRef set ["current", _nextState];
                    _smRef set ["args", _nextArgs];
                };
            };
        },
        _interval,
        [_sm]
    ] call GVAR(addPFH);

    _sm set ["pfhId", _pfhId];

    _pfhId
};

// ------------------------------------------------------------------
// PRA3_fw_stopSM
//   Params: [sm]
//   Removes the driving PFH and resets current state.
// ------------------------------------------------------------------
GVAR(stopSM) = {
    params ["_sm"];

    private _pfhId = _sm getOrDefault ["pfhId", -1];
    if (_pfhId >= 0) then {
        [_pfhId] call GVAR(removePFH);
    };

    _sm set ["pfhId", -1];
    _sm set ["current", ""];
};

diag_log "[PRA3] State machine system initialized";
