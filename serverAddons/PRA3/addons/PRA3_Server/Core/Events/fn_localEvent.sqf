#include "macros.hpp"
/*
    Project Reality ArmA 3

    Author: joko // Jonas

    Description:
    Trigger Event on a Traget

    Parameter(s):
    0: Event Name <String>
    1: Arguments <Any> (default: nil)

    Returns:
    None
*/

#ifdef isDev
    params [["_eventName", "", [""]], ["_args", []], ["_sender", "Local Called"]];

    // remove spamm events like eventadded, cursortargetchanged, playerinventorychanged from being logged
    if (toLower(_eventName) in ["eventadded", "cursortargetchanged", "playerInventoryChanged"]) then {
        DUMP("Local event: " + "Sendet from: " + _sender + "; EventName: " + _eventName)
    } else {
        DUMP("Local event: " + "Sendet from: " + _sender + "; EventName: " + _eventName + ":" + str _args)
    };
#else
    params [["_eventName", "", [""]], ["_args", []]];
#endif

_eventName = format ["PRA3_Event_%1", _eventName];
private _eventArray = GVAR(EventNamespace) getVariable _eventName;
if !(isNil "_eventArray") then {
    {
        if !(isNil "_x") then {
            _x params ["_eventFunctions", "_data"];
            if (_eventFunctions isEqualType "") then {
                _eventFunctions = parsingNamespace getVariable [_eventFunctions, {}];
            };
            [_args, _data] call _eventFunctions;
        };
        nil
    } count _eventArray;
};
nil
