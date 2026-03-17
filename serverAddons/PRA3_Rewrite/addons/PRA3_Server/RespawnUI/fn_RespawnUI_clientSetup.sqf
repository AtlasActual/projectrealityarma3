#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Master client-side initialization for the respawn screen system.
        Registers killed handler, mission start handler, screen load/unload
        logic, ticket display forwarding, and notification overlay routing.

    Called from the framework client bootstrap on machines with an interface.
*/

if (!hasInterface) exitWith {};

// Track whether the respawn screen is currently showing
GVAR(screenOpen) = false;

// ======================================================================
// 1. Player killed -> spawn as hidden temp unit, open respawn screen
// ======================================================================
["Killed", {
    // Respawn the player at a hidden off-map position as a temporary unit
    private _tempPos = [-10000, -10000, 50];
    private _grp = createGroup [playerSide, true];
    private _tempUnit = _grp createUnit [typeOf player, _tempPos, [], 0, "NONE"];

    _tempUnit setVariable [QEGVAR(Common,tempUnit), true, true];
    [_tempUnit, true] remoteExec ["hideObjectGlobal", 2];
    [_tempUnit, false] remoteExec ["enableSimulationGlobal", 2];

    selectPlayer _tempUnit;

    // Open screen on next frame to let engine settle
    [{
        private _existingDisplay = uiNamespace getVariable [QGVAR(respawnDisplay), displayNull];
        if (!isNull _existingDisplay) exitWith {
            // Screen already open, just re-fire the load event
            [UIVAR(RespawnScreen_onLoad), [_existingDisplay]] call PRA3_fw_fireEvent;
        };

        (findDisplay 46) createDisplay UIVAR(RespawnScreen);
    }] call PRA3_fw_execNextFrame;
}] call PRA3_fw_addHandler;

// ======================================================================
// 2. Mission start -> pick side with fewest players, open respawn screen
// ======================================================================
["missionStarted", {
    // Auto-select the side with fewer players
    private _bestSide = sideUnknown;
    private _bestCount = 1e6;

    {
        private _thisSide = _x;
        private _cnt = {side group _x isEqualTo _thisSide} count allPlayers;

        if (_cnt < _bestCount) then {
            _bestSide = _thisSide;
            _bestCount = _cnt;
        };
    } forEach EGVAR(Common,competingSides);

    // Move player to the chosen side via a temporary spawn unit
    private _prevUnit = player;
    private _grp = createGroup [_bestSide, true];
    private _tempUnit = _grp createUnit [typeOf player, [-1000, -1000, 10], [], 0, "NONE"];
    _tempUnit setVariable [QEGVAR(Common,tempUnit), true, true];
    [_tempUnit, true] remoteExec ["hideObjectGlobal", 2];
    [_tempUnit, false] remoteExec ["enableSimulationGlobal", 2];
    selectPlayer _tempUnit;
    deleteVehicle _prevUnit;

    // Open the respawn screen
    (findDisplay 46) createDisplay UIVAR(RespawnScreen);
}] call PRA3_fw_addHandler;

// ======================================================================
// 3. Screen onLoad: store display, init sub-modules, start camera
// ======================================================================
[UIVAR(RespawnScreen_onLoad), {
    params [["_display", displayNull]];

    uiNamespace setVariable [QGVAR(respawnDisplay), _display];
    GVAR(screenOpen) = true;

    // Suppress the weapon info HUD element while screen is open
    showHUD [true, true, true, true, true, true, false, true];

    // Initialize the four screen panels (fire sub-module load events)
    [UIVAR(SquadScreen_onLoad), [_display]] call PRA3_fw_fireEvent;
    [UIVAR(RoleScreen_onLoad), [_display]] call PRA3_fw_fireEvent;
    [UIVAR(DeploymentScreen_onLoad), [_display]] call PRA3_fw_fireEvent;

    // Wait one frame for controls to become accessible
    [{
        params ["_display"];

        if (isNull _display) exitWith {};

        // Register the map control for the marker drawing system
        private _mapCtrl = _display displayCtrl 800;
        if (!isNull _mapCtrl) then {
            // Map control available for marker module if present
        };

        // Intercept Escape key when player is dead or a temp unit
        private _isTempOrDead = !(alive player) || {player getVariable [QEGVAR(Common,tempUnit), false]};
        if (_isTempOrDead) then {
            _display displayAddEventHandler ["KeyDown", {_this call FUNC(escapeHandler)}];
        };

        // Set the mission name text on control 501
        private _missionText = getText (missionConfigFile >> "onLoadMission");
        (_display displayCtrl 501) ctrlSetStructuredText parseText _missionText;

        // Populate the ticket bar (controls 601-606)
        private _defaultTickets = getNumber (missionConfigFile >> "PRA3" >> "tickets");
        private _sideA = EGVAR(Common,competingSides) select 0;
        private _sideB = EGVAR(Common,competingSides) select 1;

        // Side A: flag (601), name (603), tickets (605)
        private _flagA = missionNamespace getVariable [format [QEGVAR(Common,Flag_%1), _sideA], ""];
        private _nameA = missionNamespace getVariable [format [QEGVAR(Common,sideName_%1), _sideA], ""];
        private _ticketsA = missionNamespace getVariable [format [QEGVAR(Tickets,count_%1), _sideA], _defaultTickets];

        (_display displayCtrl 601) ctrlSetText _flagA;
        (_display displayCtrl 603) ctrlSetText _nameA;
        (_display displayCtrl 605) ctrlSetText str _ticketsA;

        // Side B: flag (602), name (604), tickets (606)
        private _flagB = missionNamespace getVariable [format [QEGVAR(Common,Flag_%1), _sideB], ""];
        private _nameB = missionNamespace getVariable [format [QEGVAR(Common,sideName_%1), _sideB], ""];
        private _ticketsB = missionNamespace getVariable [format [QEGVAR(Tickets,count_%1), _sideB], _defaultTickets];

        (_display displayCtrl 602) ctrlSetText _flagB;
        (_display displayCtrl 604) ctrlSetText _nameB;
        (_display displayCtrl 606) ctrlSetText str _ticketsB;

        // Commit text changes instantly
        {
            (_display displayCtrl _x) ctrlCommit 0;
        } forEach [601, 602, 603, 604, 605, 606];

        // Slide in the mission name bar (500) and ticket bar (600)
        [_display displayCtrl 500] call FUNC(animateControl);
        [_display displayCtrl 600] call FUNC(animateControl);

        // Start the cinematic camera
        [QGVAR(initCamera)] call PRA3_fw_fireEvent;

    }, [_display]] call PRA3_fw_execNextFrame;
}] call PRA3_fw_addHandler;

// ======================================================================
// 4. Screen onUnload: clean up, restore HUD
// ======================================================================
[UIVAR(RespawnScreen_onUnload), {
    GVAR(screenOpen) = false;
    uiNamespace setVariable [QGVAR(respawnDisplay), displayNull];

    // Restore the full HUD
    showHUD [true, true, true, true, true, true, true, true];

    // Destroy cinematic camera
    [QGVAR(destroyCamera)] call PRA3_fw_fireEvent;
}] call PRA3_fw_addHandler;

// ======================================================================
// 5. Forward ticket change events to update the respawn display
// ======================================================================
["ticketsChanged", {
    private _display = uiNamespace getVariable [QGVAR(respawnDisplay), displayNull];
    if (isNull _display) exitWith {};

    private _defaultTickets = getNumber (missionConfigFile >> "PRA3" >> "tickets");

    private _sideA = EGVAR(Common,competingSides) select 0;
    private _sideB = EGVAR(Common,competingSides) select 1;

    private _ticketsA = missionNamespace getVariable [format [QEGVAR(Tickets,count_%1), _sideA], _defaultTickets];
    private _ticketsB = missionNamespace getVariable [format [QEGVAR(Tickets,count_%1), _sideB], _defaultTickets];

    (_display displayCtrl 605) ctrlSetText str _ticketsA;
    (_display displayCtrl 606) ctrlSetText str _ticketsB;

    {
        (_display displayCtrl _x) ctrlCommit 0;
    } forEach [605, 606];
}] call PRA3_fw_addHandler;

// ======================================================================
// 6. Notification overlay on respawn screen (controls 700, 799, 701)
// ======================================================================
["notificationDisplayed", {
    private _display = uiNamespace getVariable [QGVAR(respawnDisplay), displayNull];
    if (isNull _display || dialog) exitWith {};

    _this params ["_priority", "_timeAdded", "_text", "_color", "_duration", "_condition"];

    // Notification group container
    private _grpCtrl = _display displayCtrl 700;
    private _grpPos = ctrlPosition _grpCtrl;
    private _targetPos = +_grpPos;

    // Start from center with zero width, animate outward
    _grpPos set [0, 0.5];
    _grpPos set [2, 0];
    _grpCtrl ctrlSetPosition _grpPos;

    // Background element (799)
    private _bgCtrl = _display displayCtrl 799;
    _bgCtrl ctrlSetTextColor _color;
    private _bgPos = ctrlPosition _bgCtrl;
    private _bgStart = +_bgPos;
    _bgStart set [0, -(_bgPos select 2) / 2];
    _bgCtrl ctrlSetPosition _bgStart;
    _bgPos set [0, 0];

    // Text element (701)
    private _txtCtrl = _display displayCtrl 701;
    _txtCtrl ctrlSetStructuredText parseText format ["%1", _text];
    private _txtPos = ctrlPosition _txtCtrl;
    private _txtStart = +_txtPos;
    _txtStart set [0, -(_txtPos select 2) / 2];
    _txtCtrl ctrlSetPosition _txtStart;
    _txtPos set [0, 0];

    // Commit initial collapsed state
    _grpCtrl ctrlCommit 0;
    _bgCtrl ctrlCommit 0;
    _txtCtrl ctrlCommit 0;

    // Animate to final positions
    _grpCtrl ctrlSetPosition _targetPos;
    _grpCtrl ctrlSetFade 0;
    _grpCtrl ctrlShow true;
    _bgCtrl ctrlSetPosition _bgPos;
    _txtCtrl ctrlSetPosition _txtPos;

    _grpCtrl ctrlCommit 0.2;
    _bgCtrl ctrlCommit 0.2;
    _txtCtrl ctrlCommit 0.2;
}] call PRA3_fw_addHandler;

["notificationHidden", {
    private _display = uiNamespace getVariable [QGVAR(respawnDisplay), displayNull];
    if (isNull _display) exitWith {};

    private _grpCtrl = _display displayCtrl 700;
    _grpCtrl ctrlSetFade 1;
    _grpCtrl ctrlShow false;
    _grpCtrl ctrlCommit 0.2;
}] call PRA3_fw_addHandler;

diag_log "[PRA3 RespawnUI] Client setup complete.";
