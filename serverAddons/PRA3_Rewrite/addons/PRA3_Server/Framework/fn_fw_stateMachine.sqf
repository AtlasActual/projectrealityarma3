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
    params [["_name", ""], ["_defaultInterval", 0]];

    private _sm = createHashMap;
    _sm set ["name", _name];
    _sm set ["states", createHashMap];
    _sm set ["current", ""];
    _sm set ["args", []];
    _sm set ["pfhId", -1];
    _sm set ["defaultInterval", _defaultInterval];
    _sm set ["entryDone", false];
    _sm
};

// ------------------------------------------------------------------
// PRA3_fw_addState
//   Params: [sm, stateName, stateCode]
//   stateCode receives [args, stateName, sm] and must return either
//   a nextState string or [nextState, newArgs].
// ------------------------------------------------------------------
GVAR(addState) = {
    if (count _this >= 5) then {
        // 5-arg form: [sm, stateName, entryCode, tickCode, exitCode]
        params ["_sm", "_stateName", "_entryCode", "_tickCode", "_exitCode"];
        private _states = _sm get "states";
        _states set [_stateName, createHashMapFromArray [
            ["entry", _entryCode],
            ["tick", _tickCode],
            ["exit", _exitCode]
        ]];
    } else {
        // 3-arg form: [sm, stateName, singleCode]
        params ["_sm", "_stateName", "_stateCode"];
        private _states = _sm get "states";
        _states set [_stateName, _stateCode];
    };
};

// ------------------------------------------------------------------
// PRA3_fw_startSM
//   Params: [sm, initialState, interval]
//   interval is in seconds (0 = every frame). Starts a PFH that
//   evaluates the current state each tick.
// ------------------------------------------------------------------
GVAR(startSM) = {
    params ["_sm", "_initialState", ["_interval", -1]];

    // Use default interval from createSM if not specified
    if (_interval < 0) then {
        _interval = _sm getOrDefault ["defaultInterval", 0];
    };

    _sm set ["current", _initialState];
    _sm set ["entryDone", false];

    private _pfhId = [
        {
            params ["_args", "_pfhId"];
            _args params ["_smRef"];

            private _curState = _smRef get "current";
            if (_curState isEqualTo "") exitWith {};

            private _states = _smRef get "states";
            private _stateData = _states getOrDefault [_curState, {}];

            if (_stateData isEqualTo {}) exitWith {
                diag_log format ["[PRA3] SM warning: state '%1' has no handler", _curState];
            };

            private _smArgs = _smRef get "args";
            private _result = nil;

            // Handle both simple code blocks (3-arg addState) and
            // entry/tick/exit hashmaps (5-arg addState)
            if (_stateData isEqualType createHashMap) then {
                // 5-arg form: hashmap with entry/tick/exit
                if !(_smRef getOrDefault ["entryDone", false]) then {
                    private _entryCode = _stateData getOrDefault ["entry", {}];
                    if !(_entryCode isEqualTo {}) then {
                        [_smArgs, _curState, _smRef] call _entryCode;
                    };
                    _smRef set ["entryDone", true];
                };
                private _tickCode = _stateData getOrDefault ["tick", {}];
                if !(_tickCode isEqualTo {}) then {
                    _result = [_smArgs, _curState, _smRef] call _tickCode;
                };
            } else {
                // 3-arg form: single code block
                _result = [_smArgs, _curState, _smRef] call _stateData;
            };

            // Interpret result: string or [string, args]
            if (!isNil "_result") then {
                private _nextState = "";
                private _nextArgs = _smArgs;

                if (_result isEqualType "") then {
                    _nextState = _result;
                } else {
                    if (_result isEqualType []) then {
                        _result params [["_ns", _curState], ["_na", _smArgs]];
                        _nextState = _ns;
                        _nextArgs = _na;
                    };
                };

                if (_nextState isNotEqualTo "" && {_nextState isNotEqualTo _curState}) then {
                    // Call exit code of current state if it's a hashmap
                    if (_stateData isEqualType createHashMap) then {
                        private _exitCode = _stateData getOrDefault ["exit", {}];
                        if !(_exitCode isEqualTo {}) then {
                            [_smArgs, _curState, _smRef] call _exitCode;
                        };
                    };
                    _smRef set ["current", _nextState];
                    _smRef set ["args", _nextArgs];
                    _smRef set ["entryDone", false];
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
