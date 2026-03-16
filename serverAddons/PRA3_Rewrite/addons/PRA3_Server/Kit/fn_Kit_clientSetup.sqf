#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-side kit module initialization. Adds a GetInMan vehicle
        event handler that enforces pilot and crew kit restrictions.
        Players without the appropriate role are ejected from restricted
        vehicles and shown a notification.

    Called from the framework client bootstrap.
*/

if (!hasInterface) exitWith {};

// ======================================================================
// 1. Vehicle restriction enforcement via GetInMan EH
// ======================================================================
player addEventHandler ["GetInMan", {
    params ["_unit", "_role", "_vehicle", "_turret"];

    private _restricted = false;

    // Check pilot vehicle restriction
    if (_vehicle getVariable [QGVAR(isPilotVehicle), false]) then {
        if !(_unit getVariable [QGVAR(isPilot), false]) then {
            _restricted = true;
        };
    };

    // Check crew vehicle restriction
    if (!_restricted && {_vehicle getVariable [QGVAR(isCrewVehicle), false]}) then {
        if !(_unit getVariable [QGVAR(isCrew), false]) then {
            _restricted = true;
        };
    };

    // Eject and notify if player lacks the required kit role
    if (_restricted) then {
        _unit action ["Eject", _vehicle];

        private _msg = MLOC(VehicleRestricted);
        [_msg, [0.7, 0.1, 0.1, 0.9], 4, 1] call EFUNC(Notification,show);
    };
}];

diag_log "[PRA3 Kit] Client setup complete.";
