#include "macros.hpp"
/*
    Project Reality ArmA 3

    Author: joko // Jonas

    Description:
    Remove a Map Icon Draw Event

    Parameter(s):
    0: Group Name <String>
    1: Event Name <String>
    2: Event ID (optional) <Number>

    Returns:
    None
*/
params [["_uid", "", [""]], ["_event", "", [""]], ["_id", 0, [0]]];

// build Namespace Variablename
_eventNameSpace = format [QGVAR(MapIcon_%1_EventNamespace), _eventName];
private _namespace = missionNamespace getVariable _eventNameSpace;

private _eventArray = [_namespace, _uid, []] call FUNC(getVariable);
if (count _eventArray >= _id) exitWith {};
_eventArray set [_id, nil];

GVAR(MapGraphicsCacheBuildFlag) = GVAR(MapGraphicsCacheBuildFlag) + 1;
