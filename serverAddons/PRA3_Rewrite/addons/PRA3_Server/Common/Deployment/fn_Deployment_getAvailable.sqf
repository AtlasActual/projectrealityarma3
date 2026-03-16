#include "script_component.hpp"
/*
    FUNC(getAvailable)

    Queries the deploy point registry and returns every point the calling
    player is permitted to use. Eligibility is determined by comparing the
    point's availableFor field against the player's current side and group.

    Arguments: none

    Returns:
        Array of point ID strings
*/

private _pSide  = side group player;
private _pGroup = group player;

private _matches = [];

{
    private _avail = _y get "availableFor";
    if (_avail isEqualTo _pSide || {_avail isEqualTo _pGroup}) then {
        _matches pushBack _x;
    };
} forEach GVAR(pointStorage);

_matches
