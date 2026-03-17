#include "script_component.hpp"
/*
    FUNC(deploymentSetup)

    Description:
        Initializes the deployment panel within the respawn screen.
        Handles the spawn point list (control 403), deploy button (404),
        respawn countdown timer, map animation on selection, and
        the full deploy sequence (mutex-protected spawn execution).

    Control IDs used:
        400 - Deployment control group
        403 - Spawn point ListNBox
        404 - Deploy button
        800 - Map control

    Called from the framework client bootstrap on machines with an interface.
*/

if (!hasInterface) exitWith {};

// ======================================================================
// 1. Deployment panel onLoad: populate list, start countdown, animate in
// ======================================================================
[UIVAR(DeploymentScreen_onLoad), {
    params [["_display", displayNull]];

    uiNamespace setVariable [QGVAR(deploymentDisplay), _display];

    [{
        params ["_display"];
        if (isNull _display) exitWith {};

        // Kick off the deploy button state (timer or close label)
        [UIVAR(RespawnScreen_DeployButton_refresh)] call PRA3_fw_fireEvent;

        // Fill the deployment list with available points
        [UIVAR(RespawnScreen_DeployList_refresh)] call PRA3_fw_fireEvent;

        // Slide the deployment panel into view
        [_display displayCtrl 400] call FUNC(animateControl);

    }, [_display]] call PRA3_fw_execNextFrame;
}] call PRA3_fw_addHandler;

// ======================================================================
// 2. Deploy button state management (countdown timer / "Close" label)
// ======================================================================
[UIVAR(RespawnScreen_DeployButton_refresh), {
    private _display = uiNamespace getVariable [QGVAR(deploymentDisplay), displayNull];
    if (isNull _display) exitWith {};

    private _btnCtrl = _display displayCtrl 404;

    private _isTempOrDead = !(alive player) || {player getVariable [QEGVAR(Common,tempUnit), false]};

    if (_isTempOrDead) then {
        // Player is dead: disable button and run a countdown timer
        _btnCtrl ctrlEnable false;

        // Read the configurable respawn delay (seconds)
        private _respawnDelay = missionNamespace getVariable [QGVAR(respawnCountdown), 10];
        private _unlockTime = diag_tickTime + _respawnDelay;

        // Per-frame handler to tick down the button label
        [{
            params ["_pfhArgs", "_pfhId"];
            _pfhArgs params ["_btnCtrl", "_unlockTime"];

            // Abort if the display was closed
            private _deployDisp = uiNamespace getVariable [QGVAR(deploymentDisplay), displayNull];
            if (isNull _deployDisp) exitWith {
                [_pfhId] call PRA3_fw_removePFH;
            };

            private _remaining = _unlockTime - diag_tickTime;

            if (_remaining <= 0) exitWith {
                _btnCtrl ctrlSetText "DEPLOY";
                _btnCtrl ctrlEnable true;
                [_pfhId] call PRA3_fw_removePFH;
            };

            // Display remaining time with one decimal
            private _wholeSec = floor _remaining;
            private _fracSec = floor ((_remaining - _wholeSec) * 10);
            _btnCtrl ctrlSetText format ["%1.%2s", _wholeSec, _fracSec];

        }, 0.1, [_btnCtrl, _unlockTime]] call PRA3_fw_addPFH;
    } else {
        // Player is alive: the button acts as a "Close" action
        _btnCtrl ctrlSetText "Close";
        _btnCtrl ctrlEnable true;
    };
}] call PRA3_fw_addHandler;

// ======================================================================
// 3. Deploy button action: validate selections, mutex-protected spawn
// ======================================================================
[UIVAR(RespawnScreen_DeployButton_action), {
    private _deployDisp = uiNamespace getVariable [QGVAR(deploymentDisplay), displayNull];
    private _roleDisp = uiNamespace getVariable [QGVAR(roleDisplay), displayNull];
    if (isNull _deployDisp || isNull _roleDisp) exitWith {};

    // If player is alive and not a temp unit, just close the screen
    private _isLivePlayer = alive player && {!(player getVariable [QEGVAR(Common,tempUnit), false])};
    if (_isLivePlayer) exitWith {
        _deployDisp closeDisplay 1;
    };

    // Use a mutex to prevent race conditions during spawn
    [
        "respawn",
        {
            params ["_deployDisp", "_roleDisp"];

            // Validate: player must be in a named squad
            private _inSquad = count (units group player) > 0 && {!(isNil QEGVAR(Squad,squadIds))} && {(groupId group player) in EGVAR(Squad,squadIds)};
            if (!_inSquad) exitWith {
                [MLOC(JoinASquad), [0.7, 0.1, 0.1, 0.9], 4, 1] call EFUNC(Notification,show);
            };

            // Validate: a kit must be selected
            private _kitRow = lnbCurSelRow (_roleDisp displayCtrl 303);
            if (_kitRow < 0) exitWith {
                [MLOC(ChooseARole), [0.7, 0.1, 0.1, 0.9], 4, 1] call EFUNC(Notification,show);
            };

            // Validate: a deployment point must be selected
            private _deployListCtrl = _deployDisp displayCtrl 403;
            private _deployRow = lnbCurSelRow _deployListCtrl;
            if (_deployRow < 0) exitWith {
                [MLOC(selectSpawn), [0.7, 0.1, 0.1, 0.9], 4, 1] call EFUNC(Notification,show);
            };

            // Retrieve the stored deployment point identifier
            private _pointId = _deployListCtrl lnbData [_deployRow, 0];

            // Ask the Deployment module to consume a spawn ticket
            private _spawnData = [_pointId] call EFUNC(Deployment,consumeSpawn);
            if (isNil "_spawnData") exitWith {
                ["Spawn point no longer available", [0.7, 0.1, 0.1, 0.9], 4, 1] call EFUNC(Notification,show);
            };

            private _spawnPos = _spawnData;

            // Close the screen before spawning
            _deployDisp closeDisplay 1;

            // Execute the spawn on next frame
            [{
                params ["_spawnPos"];

                // Perform the actual respawn at the deployment position
                [player, _spawnPos] call EFUNC(Respawn,execute);

                // Apply the selected kit on the following frame
                [{
                    private _kitConfig = player getVariable [QEGVAR(Kit,selectedKit), ""];
                    if (_kitConfig isNotEqualTo "") then {
                        [player, _kitConfig] call EFUNC(Kit,equip);
                    };
                }] call PRA3_fw_execNextFrame;

            }, [_spawnPos]] call PRA3_fw_execNextFrame;
        },
        [_deployDisp, _roleDisp]
    ] call PRA3_fw_mutexLock;
}] call PRA3_fw_addHandler;

// ======================================================================
// 4. Deployment list refresh (rebuild the ListNBox with current points)
// ======================================================================
[UIVAR(RespawnScreen_DeployList_refresh), {
    private _display = uiNamespace getVariable [QGVAR(deploymentDisplay), displayNull];
    if (isNull _display) exitWith {};

    // Gather available deployment points from the Deployment module
    private _availablePoints = call EFUNC(Deployment,getAvailable);

    private _listData = [];
    {
        private _pointId = _x;

        // Fetch point metadata: name, remaining tickets, icon path
        private _pointInfo = [_pointId, "all"] call EFUNC(Deployment,getData);
        if (isNil "_pointInfo") then { continue };
        private _name = _pointInfo getOrDefault ["name", "Unknown"];
        private _tickets = _pointInfo getOrDefault ["spawnTickets", -1];
        private _icon = _pointInfo getOrDefault ["icon", ""];

        // Append ticket count to the name if tickets are limited
        private _label = if (_tickets > 0) then {
            format ["%1 (%2)", _name, _tickets]
        } else {
            _name
        };

        _listData pushBack [[_label], _pointId, _icon];
    } forEach _availablePoints;

    // Populate the ListNBox, preserving the previous selection if possible
    [_display displayCtrl 403, _listData] call FUNC(populateList);
}] call PRA3_fw_addHandler;

// ======================================================================
// 5. React to deploy point additions, removals, and ticket changes
// ======================================================================
["deployPointAdded", {
    [UIVAR(RespawnScreen_DeployList_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

["deployPointRemoved", {
    [UIVAR(RespawnScreen_DeployList_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

["ticketsChanged", {
    [UIVAR(RespawnScreen_DeployList_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

// Refresh the list when the player changes group (rally points may differ)
["groupChanged", {
    [UIVAR(RespawnScreen_DeployList_refresh)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

// ======================================================================
// 6. Selection changed: animate map to the chosen point's position
// ======================================================================
[UIVAR(RespawnScreen_SpawnPointList_onLBSelChanged), {
    private _display = uiNamespace getVariable [QGVAR(deploymentDisplay), displayNull];
    if (isNull _display) exitWith {};

    private _listCtrl = _display displayCtrl 403;
    private _selRow = lnbCurSelRow _listCtrl;
    if (_selRow < 0) exitWith {};

    // Retrieve the point identifier from the stored data
    private _pointId = _listCtrl lnbData [_selRow, 0];

    // Fetch position from the Deployment module
    private _pointInfo = [_pointId, "position"] call EFUNC(Deployment,getData);
    private _targetPos = _pointInfo select 0;

    // Smoothly pan the map to the selected point
    private _mapCtrl = _display displayCtrl 800;
    _mapCtrl ctrlMapAnimAdd [0.5, 0.15, _targetPos];
    ctrlMapAnimCommit _mapCtrl;
}] call PRA3_fw_addHandler;

diag_log "[PRA3 RespawnUI] Deployment setup complete.";
