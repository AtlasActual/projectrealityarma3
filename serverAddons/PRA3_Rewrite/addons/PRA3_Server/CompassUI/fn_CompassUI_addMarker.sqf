#include "script_component.hpp"
/*
    FUNC(addMarker)

    Description:
        Stores a line marker entry in the compass marker registry.
        The marker will be rendered as a coloured indicator on the
        compass strip pointing toward the given world position.

    Arguments:
        0: _markerId  - unique string identifier          (String)
        1: _color     - RGBA colour array [r,g,b,a]       (Array)
        2: _position  - world position [x,y,z]             (Array)

    Returns: nothing
*/

params ["_markerId", "_color", "_position"];

if (isNil "_markerId" || {_markerId isEqualTo ""}) exitWith {
    diag_log "[PRA3 CompassUI] addMarker: invalid markerId, skipping.";
};

GVAR(lineMarkers) set [_markerId, [_color, _position]];
