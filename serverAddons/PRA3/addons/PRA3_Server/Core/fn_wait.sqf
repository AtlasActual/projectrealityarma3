#include "macros.hpp"
/*
 * Author: EstelDudleDain edit by joko // Jonas
 * wait a time and execute script
 *
 * Arguments:
 * 0: Code that get Executed if the Conditon is True <Code>
 * 1: Time to Wait <Number>
 * 2: Paramter <Any>
 *
 * Return Value:
 * None
 *
 * Example:
 * [{hint "you die"},10,player] call CFUNC(wait);
 */
params ["_code", "_time", ["_args", []]];
GVAR(waitArray) pushBack [_time + time, _code, _args];
GVAR(waitArray) sort true;
