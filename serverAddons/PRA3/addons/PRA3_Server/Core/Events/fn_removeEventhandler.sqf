#include "macros.hpp"
/*
    Project Reality ArmA 3

    Author: joko // Jonas

    Description:
    Remove Eventhandler

    Parameter(s):
    0: Event Name <String>
    1: ID

    Returns:
    is Removed <Bool>
*/
params [["_eventName", "", [""]], ["_id", -1, [-1]]];

DUMP("Eventhandler Removed: "+ _eventName)
_event = format ["PRA3_Event_%1", _eventName];
private _eventArray = [GVAR(EventNamespace), _event, []] call FUNC(getVariable);
if (count _eventArray >= _id) then {
    _eventArray set [_id, nil];
    GVAR(EventNamespace) setVariable [_event, _eventArray];
    true
} else {
    false
};
