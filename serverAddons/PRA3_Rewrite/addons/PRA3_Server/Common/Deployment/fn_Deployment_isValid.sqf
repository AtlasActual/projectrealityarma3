#include "script_component.hpp"
/*
    FUNC(isValid)

    Tests whether a deploy point with the supplied ID currently exists in
    the central registry.

    Arguments:
        0: _pointId  - identifier to check  (String)

    Returns:
        Boolean — true when the point is registered, false otherwise
*/

params ["_pointId"];

_pointId in GVAR(pointStorage)
