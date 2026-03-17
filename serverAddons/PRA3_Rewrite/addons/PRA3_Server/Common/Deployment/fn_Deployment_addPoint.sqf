#include "script_component.hpp"
/*
    FUNC(addPoint)

    Registers a brand-new deploy point in the central registry. Builds a
    deterministic unique ID from the point's type, name, and floored X
    coordinate, assembles a HashMap of all fields, stores it, and broadcasts
    the "deployPointAdded" event to every connected machine.

    Arguments:
        0: _name          - human-readable label              (String)
        1: _type          - category tag e.g. "BASE","FOB"    (String)
        2: _position      - world coordinates [x,y,z]         (Array)
        3: _availableFor  - restricting side or group          (Side|Group)
        4: _spawnTickets  - remaining spawns, -1 = infinite   (Number)
        5: _icon          - UI icon classname                  (String)
        6: _mapIcon       - map marker type                   (String)
        7: _objects       - tied world objects                 (Array)
        8: _customData    - arbitrary extra data               (HashMap)

    Returns:
        _pointId  (String)
*/

params [
    "_name",
    "_type",
    "_position",
    "_availableFor",
    ["_spawnTickets", -1],
    ["_icon", "iconBase"],
    ["_mapIcon", "mil_flag"],
    ["_objects", []],
    ["_customData", nil]
];

// Guarantee customData is always a valid HashMap
if (isNil "_customData") then {
    _customData = createHashMap;
};

// Derive a repeatable identifier from the point metadata
private _pointId = format ["%1_%2_%3_%4", _type, _name, floor (_position select 0), floor (_position select 1)];

// Pack every field into a single HashMap record
private _entry = createHashMap;
_entry set ["name",         _name];
_entry set ["type",         _type];
_entry set ["position",     _position];
_entry set ["availableFor", _availableFor];
_entry set ["spawnTickets", _spawnTickets];
_entry set ["icon",         _icon];
_entry set ["mapIcon",      _mapIcon];
_entry set ["objects",      _objects];
_entry set ["customData",   _customData];

// Commit to the central registry
GVAR(pointStorage) set [_pointId, _entry];

// Broadcast creation event
["deployPointAdded", [_pointId]] call FWFUNC(fireGlobal);

diag_log format ["[PRA3] [Deployment] Added point '%1' — type: %2, pos: %3", _pointId, _type, _position];

_pointId
