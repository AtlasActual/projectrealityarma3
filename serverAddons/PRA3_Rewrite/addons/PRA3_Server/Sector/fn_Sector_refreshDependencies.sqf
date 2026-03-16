#include "script_component.hpp"
/*
    FUNC(refreshDependencies)

    Description:
        Server-only. Re-evaluates which sectors are currently contestable
        based on the AAS dependency chain. Starts capture-loop PFHs for
        newly active sectors and stops them for sectors that are no longer
        reachable by any competing side.

        Maintains GVAR(activePFHs) as a HashMap mapping sector names to
        their running PFH handle IDs.

    Called after initial setup and whenever "sectorOwnerChanged" fires.
*/

if (!isServer) exitWith {};

private _competingSides = EGVAR(Common,competingSides);

{
    private _sector = _x;
    private _sectorName = _sector getVariable [QGVAR(name), ""];
    private _ownerSide  = _sector getVariable [QGVAR(ownerSide), sideUnknown];

    // Determine if any non-owning side can contest this sector
    private _isContestable = false;
    {
        if (!(_x isEqualTo _ownerSide)) then {
            if ([_sector, _x] call FUNC(canCapture)) exitWith {
                _isContestable = true;
            };
        };
    } forEach _competingSides;

    private _currentPFH = GVAR(activePFHs) getOrDefault [_sectorName, -1];

    if (_isContestable) then {
        // Sector should have an active capture loop
        if (_currentPFH isEqualTo -1) then {
            // Create args array, then patch in the PFH id after creation
            private _pfhArgs = [_sector, -1];
            private _newPFH = [{
                _this call FUNC(captureLoop);
            }, 0.5, _pfhArgs] call PRA3_fw_addPFH;
            _pfhArgs set [1, _newPFH];

            GVAR(activePFHs) set [_sectorName, _newPFH];

            diag_log format [
                "[PRA3 Sector] Started capture loop for '%1' (PFH %2)",
                _sectorName, _newPFH
            ];
        };
    } else {
        // Sector should not be contested -- stop its PFH if running
        if !(_currentPFH isEqualTo -1) then {
            [_currentPFH] call PRA3_fw_removePFH;
            GVAR(activePFHs) set [_sectorName, -1];

            // Reset attacking side since no one can contest
            _sector setVariable [QGVAR(attackingSide), sideUnknown, true];

            diag_log format [
                "[PRA3 Sector] Stopped capture loop for '%1'",
                _sectorName
            ];
        };
    };

} forEach GVAR(sectorList);
