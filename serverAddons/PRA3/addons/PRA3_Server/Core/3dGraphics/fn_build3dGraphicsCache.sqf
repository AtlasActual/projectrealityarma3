#include "macros.hpp"
/*
    Project Reality ArmA 3

    Author: BadGuy

    Description:
    Updates the 3dGraphicsCache

    Parameter(s):
    -

    Returns:
    -
*/
private _cache = [];

{
    _cache append (GVAR(3dGraphicsNamespace) getVariable _x);
    nil;
} count ([GVAR(3dGraphicsNamespace)] call CFUNC(allVariables));

GVAR(3dGraphicsCache) = +_cache;
