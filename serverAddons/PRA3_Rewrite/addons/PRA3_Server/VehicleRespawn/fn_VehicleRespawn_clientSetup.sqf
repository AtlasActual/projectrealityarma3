#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-side vehicle respawn integration. Listens for the
        "vehicleAvailable" event and displays a notification to the
        player with the vehicle type name. Also fixes JIP vehicle
        variable name synchronisation issues.

    Called once per client during module init.
*/

if (!hasInterface) exitWith {};

// ======================================================================
// 1. Vehicle available notification
// ======================================================================
["vehicleAvailable", {
    params [["_vehicleName", "Vehicle"]];

    private _text = format [EMLOC(VehicleRespawn,VehicleReady), _vehicleName];

    // Use the notification subsystem if available
    if (!isNil QEFUNC(Notification,show)) then {
        ["vehicleReady", _text, 5] call EFUNC(Notification,show);
    } else {
        systemChat _text;
    };
}] call PRA3_fw_addHandler;

// ======================================================================
// 2. JIP vehicle variable name fix
// ======================================================================
// When joining in progress, vehicle variable names set via
// setVehicleVarName on the server may not be properly resolved on
// the client. Walk through all vehicles and re-link names.
[{
    if (isNull player) exitWith {};

    {
        private _veh = _x;
        private _vName = vehicleVarName _veh;

        // If the variable name exists but the missionNamespace binding
        // points to null or a different object, rebind it
        if (_vName isNotEqualTo "") then {
            private _current = missionNamespace getVariable [_vName, objNull];
            if (isNull _current || {_current isNotEqualTo _veh}) then {
                missionNamespace setVariable [_vName, _veh];
            };
        };
    } forEach vehicles;

    diag_log "[PRA3 VehicleRespawn] JIP vehicle variable names synchronized.";
}, 3, []] call PRA3_fw_waitAndExec;

diag_log "[PRA3 VehicleRespawn] Client setup complete.";
