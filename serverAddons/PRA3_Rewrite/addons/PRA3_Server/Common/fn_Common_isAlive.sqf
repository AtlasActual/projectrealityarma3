#include "script_component.hpp"
/*
    PRA3_fnc_Common_isAlive

    Description:
        Returns whether a unit is both alive and not in an unconscious
        (downed / incapacitated) state from the Revive system.

    Parameters:
        _unit - Object : the unit to check

    Returns:
        Boolean - true if the unit is alive and conscious
*/

params [["_unit", objNull, [objNull]]];

alive _unit && {!(_unit getVariable [QEGVAR(Revive,unconscious), false])}
