#include "script_component.hpp"
/*
    FUNC(removeMarker)

    Description:
        Removes a line marker from the compass marker registry so it
        is no longer rendered on the compass strip.

    Arguments:
        0: _markerId  - identifier of the marker to remove  (String)

    Returns: nothing
*/

params ["_markerId"];

if (isNil "_markerId" || {_markerId isEqualTo ""}) exitWith {};

GVAR(lineMarkers) set [_markerId, nil];
