#include "script_component.hpp"
/*
    FUNC(getForSide)

    Returns every deploy point whose availableFor field matches the
    requested side value.

    Arguments:
        0: _side  - the side to filter on  (Side)

    Returns:
        Array of point ID strings
*/

params ["_side"];

private _matches = [];

{
    if ((_y get "availableFor") isEqualTo _side) then {
        _matches pushBack _x;
    };
} forEach GVAR(pointStorage);

_matches
