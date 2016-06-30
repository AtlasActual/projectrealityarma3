#include "macros.hpp"
/*
    Project Reality ArmA 3

    Author: joko // Jonas

    Description:
    Remove a Position from the Compass

    Parameter(s):
    0: Marker ID <String>

    Returns:
    None
*/
params ["_id"];
[GVAR(lineMarkers), _id, nil, QGVAR(lineMarkersCache)] call CFUNC(setVariable);
