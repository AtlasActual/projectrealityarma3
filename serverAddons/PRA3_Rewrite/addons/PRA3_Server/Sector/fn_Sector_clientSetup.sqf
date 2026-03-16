#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-only sector interaction setup. Adds a per-frame handler
        that checks the player's position against all sector markers,
        fires enter/leave events, and registers notification handlers
        for ownership changes.

    Called from FUNC(init) once GVAR(setupDone) is true.
*/

if (!hasInterface) exitWith {};

// Track which sector the player is currently inside (objNull = none)
GVAR(currentSector) = objNull;

// ======================================================================
// 1. Position-checking PFH (0.1s interval)
// ======================================================================
[{
    params ["_args", "_pfhId"];

    if (isNull player) exitWith {};

    private _foundSector = objNull;

    {
        private _sector = _x;
        private _marker = _sector getVariable [QGVAR(marker), ""];

        if (_marker isEqualTo "") then { continue };

        if (player inArea _marker) exitWith {
            _foundSector = _sector;
        };
    } forEach GVAR(sectorList);

    private _prevSector = GVAR(currentSector);

    // Player moved into a different sector (or out of all sectors)
    if (!(_foundSector isEqualTo _prevSector)) then {
        // Left previous sector
        if (!isNull _prevSector) then {
            GVAR(currentSector) = objNull;
            ["sectorLeft", [player, _prevSector]] call PRA3_fw_fireEvent;
            ["sectorLeft", [player, _prevSector]] call PRA3_fw_fireServer;

            // Hide the capture HUD
            [false, _prevSector] call FUNC(captureHUD);
        };

        // Entered new sector
        if (!isNull _foundSector) then {
            GVAR(currentSector) = _foundSector;
            ["sectorEntered", [player, _foundSector]] call PRA3_fw_fireEvent;
            ["sectorEntered", [player, _foundSector]] call PRA3_fw_fireServer;

            // Show the capture HUD
            [true, _foundSector] call FUNC(captureHUD);
        };
    };
}, 0.1, []] call PRA3_fw_addPFH;

// ======================================================================
// 2. Ownership change notifications
// ======================================================================
["sectorOwnerChanged", {
    params ["_sector", "_oldSide", "_newSide"];

    if (isNull player) exitWith {};

    private _sectorFullName = _sector getVariable [QGVAR(fullName), "Sector"];
    private _playerSide = side group player;

    if (_newSide isEqualTo sideUnknown) then {
        // Sector was neutralized
        if (_oldSide isEqualTo _playerSide) then {
            systemChat format ["%1 has been neutralized!", _sectorFullName];
        } else {
            systemChat format ["%1 has been neutralized.", _sectorFullName];
        };
    } else {
        if (_newSide isEqualTo _playerSide) then {
            // Our side captured it
            systemChat format ["%1 has been captured!", _sectorFullName];
        } else {
            // Enemy captured it
            if (_oldSide isEqualTo _playerSide) then {
                systemChat format ["%1 has been lost!", _sectorFullName];
            } else {
                systemChat format ["%1 has been captured by the enemy.", _sectorFullName];
            };
        };
    };

    // Redraw all sectors to reflect new ownership
    {
        [_x] call FUNC(draw);
    } forEach GVAR(sectorList);

}] call PRA3_fw_addHandler;

diag_log "[PRA3 Sector] Client setup complete.";
