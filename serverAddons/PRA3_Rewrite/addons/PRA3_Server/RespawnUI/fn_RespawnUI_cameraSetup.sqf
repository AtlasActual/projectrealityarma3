#include "script_component.hpp"
/*
    FUNC(cameraSetup)

    Description:
        Cinematic camera system for the respawn screen background.
        Creates a camera that flies over sectors owned by the player's
        side, cycling through them with smooth interpolated movement.
        Falls back to orbiting a base spawn position when no sectors
        are available.

    Called from the framework client bootstrap on machines with an interface.
*/

if (!hasInterface) exitWith {};

// Camera state variables
GVAR(camera) = objNull;
GVAR(currentCameraTarget) = objNull;
GVAR(cameraMovePFH) = -1;

// ======================================================================
// 1. Start camera when respawn screen opens (if player is dead/temp)
// ======================================================================
[UIVAR(RespawnScreen_onLoad), {
    private _isTempOrDead = !(alive player) || {player getVariable [QEGVAR(Common,tempUnit), false]};
    if (_isTempOrDead) then {
        [QGVAR(initCamera)] call PRA3_fw_fireEvent;
    };
}] call PRA3_fw_addHandler;

// Reinitialize camera when the player switches side
["playerSideChanged", {
    if (isNull GVAR(camera)) exitWith {};

    [QGVAR(destroyCamera)] call PRA3_fw_fireEvent;
    [QGVAR(initCamera)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

// Destroy camera when screen closes
[UIVAR(RespawnScreen_onUnload), {
    [QGVAR(destroyCamera)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

// If a sector changes ownership, check if it was the camera target
["sectorSideChanged", {
    _this params ["_sector"];

    if (_sector isEqualTo GVAR(currentCameraTarget)) then {
        [QGVAR(pickNextTarget)] call PRA3_fw_fireEvent;
    };
}] call PRA3_fw_addHandler;

// ======================================================================
// 2. Camera initialization
// ======================================================================
[QGVAR(initCamera), {
    // Determine starting position: the base sector for the player's side
    private _baseName = format ["base_%1", playerSide];
    private _baseObj = objNull;

    // Try to find the base sector through the Sector module
    {
        if ((str _x) find _baseName >= 0) exitWith {
            _baseObj = _x;
        };
    } forEach (missionNamespace getVariable [QEGVAR(Sector,allSectorsArray), []]);

    // Fallback: use map center if no base sector found
    private _startPos = if (!isNull _baseObj) then {
        getPos _baseObj
    } else {
        [worldSize / 2, worldSize / 2, 0]
    };

    GVAR(currentCameraTarget) = _baseObj;

    // Elevate to camera flight height
    private _camHeight = 10;
    _startPos set [2, _camHeight];

    // Create and activate the camera
    GVAR(camera) = "camera" camCreate _startPos;
    GVAR(camera) cameraEffect ["INTERNAL", "BACK"];
    showCinemaBorder false;

    // Start a per-second handler that moves the camera toward targets
    private _moveSpeed = 5;

    GVAR(cameraMovePFH) = [{
        if (isNull GVAR(camera)) exitWith {};

        private _speed = 5;
        private _height = 10;

        // Get the target position
        private _targetPos = if (!isNull GVAR(currentCameraTarget)) then {
            getPos GVAR(currentCameraTarget)
        } else {
            [worldSize / 2, worldSize / 2, 0]
        };
        _targetPos set [2, _height];

        private _curPos = getPos GVAR(camera);

        // Compute direction vector and next position along the path
        private _diff = _targetPos vectorDiff _curPos;
        private _dir = vectorNormalized _diff;
        private _nextPos = _curPos vectorAdd (_dir vectorMultiply _speed);
        _nextPos set [2, _height];

        // Check if we would overshoot the target
        private _distToTarget = _curPos distance _targetPos;
        private _distToNext = _curPos distance _nextPos;

        if (_distToNext >= _distToTarget) then {
            _nextPos = _targetPos;

            // Arrived at target: pick the next one
            [QGVAR(pickNextTarget)] call PRA3_fw_fireEvent;
        };

        // Skip if there is no meaningful movement
        if (_curPos distance _nextPos < 0.01) exitWith {};

        // Commit the smooth camera movement
        private _commitTime = _speed / (_curPos distance _nextPos);
        GVAR(camera) camSetPos _nextPos;
        GVAR(camera) camCommit _commitTime;

    }, 1] call PRA3_fw_addPFH;
}] call PRA3_fw_addHandler;

// ======================================================================
// 3. Pick the next camera target from owned sectors
// ======================================================================
[QGVAR(pickNextTarget), {
    private _allSectors = missionNamespace getVariable [QEGVAR(Sector,allSectorsArray), []];

    // Filter to sectors owned by the player's side that are connected
    // to the current target via dependency chains
    private _candidates = _allSectors select {
        private _sectorSide = _x getVariable ["side", sideUnknown];
        private _deps = (_x getVariable ["dependency", []]);

        _sectorSide isEqualTo playerSide && {
            isNull GVAR(currentCameraTarget) || {
                (str GVAR(currentCameraTarget)) in (_deps apply { str _x })
            }
        }
    };

    if (count _candidates > 0) then {
        GVAR(currentCameraTarget) = selectRandom _candidates;

        // Orient the camera perpendicular to the movement direction,
        // facing away from the map center for a cinematic sweep effect
        private _curPos = getPos GVAR(camera);
        private _tgtPos = getPos GVAR(currentCameraTarget);

        private _toTarget = _tgtPos vectorDiff _curPos;
        private _toCenter = [worldSize / 2, worldSize / 2, 0] vectorDiff _curPos;

        private _bearingTarget = ((_toTarget select 0) atan2 (_toTarget select 1) + 360) mod 360;
        private _bearingCenter = ((_toCenter select 0) atan2 (_toCenter select 1) + 360) mod 360;

        private _angleDelta = (((_bearingTarget - _bearingCenter) + 180) mod 360) - 180;

        // Point camera 90 degrees to the side, away from world center
        private _camDir = if (_angleDelta < 0) then {
            _bearingTarget + 90
        } else {
            _bearingTarget - 90
        };

        GVAR(camera) setDir _camDir;
    };
}] call PRA3_fw_addHandler;

// ======================================================================
// 4. Camera destruction and cleanup
// ======================================================================
[QGVAR(destroyCamera), {
    // Remove the movement per-frame handler
    if (GVAR(cameraMovePFH) >= 0) then {
        [GVAR(cameraMovePFH)] call PRA3_fw_removePFH;
        GVAR(cameraMovePFH) = -1;
    };

    // Terminate and destroy the camera object
    if (!isNull GVAR(camera)) then {
        GVAR(camera) cameraEffect ["TERMINATE", "BACK"];
        camDestroy GVAR(camera);
        GVAR(camera) = objNull;
    };

    GVAR(currentCameraTarget) = objNull;
}] call PRA3_fw_addHandler;

diag_log "[PRA3 RespawnUI] Camera setup complete.";
