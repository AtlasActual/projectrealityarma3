#include "macros.hpp"
/*
    Project Reality ArmA 3

    Author: joko // Jonas

    Description:
    Start a Statemachine.

    Parameter(s):
    0: Statemachine Object <Location>
    1: First State <String> (default: "init")
    2: Tick Time <Number> (default: 0)

    Returns:
    Index of the Statemachine PFH <Number>
*/
params ["_stateMachine", "_firstState", ["_tickeTime", 0]];

if !(isNil "_firstState") then {
    _stateMachine setVariable [SMSVAR(nextStateData), _firstState];
};

[{
    private _ret = _this call FUNC(stepStatemachine);
    if (_ret in EGVAR(Statemachine,exitStateNames)) then {
        (_this select 1) call CFUNC(removePerFrameHandler);
    };
}, _tickeTime, _stateMachine] call CFUNC(addPerFrameHandler);
