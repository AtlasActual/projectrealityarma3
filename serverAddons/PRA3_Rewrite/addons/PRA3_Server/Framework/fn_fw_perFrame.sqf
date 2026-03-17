#include "script_component.hpp"
/*
    PRA3_fnc_fw_perFrame

    Description:
        Per-frame handler manager. Wraps a single "EachFrame"
        MissionEventHandler that iterates all registered handlers,
        supporting intervals, one-shot next-frame execution,
        delayed execution, and conditional wait-until execution.

    Called during framework bootstrap.
*/

// Registry: id -> [code, interval, args, nextRunTime, type]
// type: "pfh" | "nextframe" | "wait" | "waituntil"
// For waituntil: [code, interval(unused), args, unused, "waituntil", conditionCode]
GVAR(pfhRegistry) = createHashMap;
GVAR(pfhNextId) = 0;

// ------------------------------------------------------------------
// Single EachFrame MEH that drives everything
// ------------------------------------------------------------------
addMissionEventHandler ["EachFrame", {
    private _tick = diag_tickTime;
    private _registry = GVAR(pfhRegistry);
    private _toRemove = [];

    {
        private _id = _x;
        private _entry = _registry get _id;

        if (isNil "_entry") then { continue };

        _entry params ["_code", "_interval", "_args", "_nextRun", "_type"];

        switch (_type) do {
            case "pfh": {
                if (_tick >= _nextRun) then {
                    [_args, _id] call _code;
                    // Schedule next run
                    if (_interval > 0) then {
                        _entry set [3, _tick + _interval];
                    } else {
                        _entry set [3, 0];
                    };
                };
            };

            case "nextframe": {
                _args call _code;
                _toRemove pushBack _id;
            };

            case "wait": {
                if (_tick >= _nextRun) then {
                    _args call _code;
                    _toRemove pushBack _id;
                };
            };

            case "waituntil": {
                private _condCode = _entry select 5;
                if (_args call _condCode) then {
                    _args call _code;
                    _toRemove pushBack _id;
                };
            };
        };
    } forEach (keys _registry);

    // Clean up one-shot entries
    {
        _registry deleteAt _x;
    } forEach _toRemove;
}];

// ------------------------------------------------------------------
// PRA3_fw_addPFH
//   Params: [code, interval, args]
//   interval 0 = every frame
//   Returns: handler ID
// ------------------------------------------------------------------
GVAR(addPFH) = {
    params ["_code", ["_interval", 0], ["_args", []]];

    private _id = GVAR(pfhNextId);
    GVAR(pfhNextId) = _id + 1;

    private _nextRun = if (_interval > 0) then {
        diag_tickTime + _interval
    } else {
        0
    };

    GVAR(pfhRegistry) set [_id, [_code, _interval, _args, _nextRun, "pfh"]];

    _id
};

// ------------------------------------------------------------------
// PRA3_fw_removePFH
//   Params: [id]
// ------------------------------------------------------------------
GVAR(removePFH) = {
    private _id = if (_this isEqualType []) then { _this select 0 } else { _this };

    GVAR(pfhRegistry) deleteAt _id;
};

// ------------------------------------------------------------------
// PRA3_fw_execNextFrame
//   Params: [code, args]
//   Runs code exactly once on the next frame.
// ------------------------------------------------------------------
GVAR(execNextFrame) = {
    params ["_code", ["_args", []]];

    private _id = GVAR(pfhNextId);
    GVAR(pfhNextId) = _id + 1;

    GVAR(pfhRegistry) set [_id, [_code, 0, _args, 0, "nextframe"]];

    _id
};

// ------------------------------------------------------------------
// PRA3_fw_waitAndExec
//   Params: [code, delay, args]
//   Waits delay seconds then runs code once.
// ------------------------------------------------------------------
GVAR(waitAndExec) = {
    params ["_code", ["_delay", 0], ["_args", []]];

    private _id = GVAR(pfhNextId);
    GVAR(pfhNextId) = _id + 1;

    private _runAt = diag_tickTime + _delay;

    GVAR(pfhRegistry) set [_id, [_code, 0, _args, _runAt, "wait"]];

    _id
};

// ------------------------------------------------------------------
// PRA3_fw_waitUntilExec
//   Params: [code, conditionCode, args]
//   Checks conditionCode each frame; when it returns true, runs code
//   once and auto-removes.
// ------------------------------------------------------------------
GVAR(waitUntilExec) = {
    params ["_condCode", "_code", ["_args", []]];

    private _id = GVAR(pfhNextId);
    GVAR(pfhNextId) = _id + 1;

    // Entry has extra element at index 5 for the condition code
    GVAR(pfhRegistry) set [_id, [_code, 0, _args, 0, "waituntil", _condCode]];

    _id
};

diag_log "[PRA3] Per-frame handler system initialized";
