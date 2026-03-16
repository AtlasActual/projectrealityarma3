#include "script_component.hpp"
/*
    FUNC(init)

    Description:
        Ticket and scoring system initialisation. Runs on every machine.
        Reads scoring configuration from missionConfigFile >> "PRA3",
        sets up server-side ticket tracking and deduction logic, and
        creates the client-side HUD for displaying ticket counts.

    Called during CfgFunctions preInit.
*/

// ======================================================================
// 1. Read scoring configuration from mission config
// ======================================================================
private _cfgRoot = missionConfigFile >> "PRA3";

GVAR(startingTickets)    = getNumber (_cfgRoot >> "tickets");
GVAR(ticketBleedInterval) = getArray (_cfgRoot >> "ticketBleed") param [0, 30];
GVAR(ticketBleedAmount)  = getArray (_cfgRoot >> "ticketBleed") param [1, 1];
GVAR(musicStartThreshold) = getNumber (_cfgRoot >> "musicStart");
GVAR(playerTicketCost)   = getNumber (_cfgRoot >> "playerTicketValue");

// Apply sane defaults when config values are missing or zero
if (GVAR(startingTickets) isEqualTo 0) then {
    GVAR(startingTickets) = 800;
};
if (GVAR(musicStartThreshold) isEqualTo 0) then {
    GVAR(musicStartThreshold) = 50;
};
if (GVAR(playerTicketCost) isEqualTo 0) then {
    GVAR(playerTicketCost) = 1;
};

// Bleed PFH handle (server only, -1 means not running)
GVAR(bleedPFH) = -1;

// Music state (client only)
GVAR(endMusicPlaying) = false;

diag_log format [
    "[PRA3 Tickets] Config loaded: start=%1 bleed=[%2,%3] musicAt=%4 playerCost=%5",
    GVAR(startingTickets),
    GVAR(ticketBleedInterval),
    GVAR(ticketBleedAmount),
    GVAR(musicStartThreshold),
    GVAR(playerTicketCost)
];

// ======================================================================
// 2. Wait for competing sides then proceed with setup
// ======================================================================
[{
    private _sides = missionNamespace getVariable [QEGVAR(Common,competingSides), []];
    !(_sides isEqualTo [])
}, {
    private _sides = EGVAR(Common,competingSides);

    // ==================================================================
    // 3. Server-side: initialise ticket counts and event handlers
    // ==================================================================
    if (isServer) then {

        // Set starting ticket count for each competing side
        {
            private _varName = format [QGVAR(count_%1), _x];
            missionNamespace setVariable [_varName, GVAR(startingTickets)];
            publicVariable _varName;
        } forEach _sides;

        diag_log format [
            "[PRA3 Tickets] Server: ticket counts initialised for %1 sides.",
            count _sides
        ];

        // --------------------------------------------------------------
        // 3a. EntityKilled handler -- deduct tickets on death
        // --------------------------------------------------------------
        addMissionEventHandler ["EntityKilled", {
            params ["_killed", "_killer", "_instigator"];

            // Determine the side that loses tickets
            private _losingSide = side group _killed;
            private _sides = EGVAR(Common,competingSides);

            // Only process entities belonging to a competing side
            if !(_losingSide in _sides) exitWith {};

            // Check for a custom ticket value on the entity
            private _entityTicketCost = _killed getVariable [QGVAR(ticketValue), 0];

            if (_entityTicketCost > 0) then {
                [_losingSide, -_entityTicketCost] call FUNC(modify);
            };

            // Additional player death cost
            if (isPlayer _killed) then {
                [_losingSide, -(GVAR(playerTicketCost))] call FUNC(modify);
            };
        }];

        // --------------------------------------------------------------
        // 3b. Sector ownership change -- deduct tickets from losing side
        // --------------------------------------------------------------
        ["sectorOwnerChanged", {
            params ["_sector", "_oldSide", "_newSide"];

            private _ticketVal = _sector getVariable [QEGVAR(Sector,ticketValue), 0];

            // The side that lost the sector pays the ticket cost
            if (_ticketVal > 0 && {!(_oldSide isEqualTo sideUnknown)}) then {
                [_oldSide, -_ticketVal] call FUNC(modify);
            };

            // Evaluate ticket bleed conditions after ownership shift
            [] call GVAR(evaluateBleed);
        }] call PRA3_fw_addHandler;

        // --------------------------------------------------------------
        // 3c. Ticket bleed evaluation function
        //     When one side holds nearly all sectors, start draining
        //     the disadvantaged side's tickets at a steady rate.
        // --------------------------------------------------------------
        GVAR(evaluateBleed) = {
            private _sides = EGVAR(Common,competingSides);
            private _sectorList = missionNamespace getVariable [QEGVAR(Sector,sectorList), []];
            private _totalSectors = count _sectorList;

            if (_totalSectors <= 0) exitWith {};

            // Count sectors owned by each side
            private _ownershipCount = createHashMap;
            {
                _ownershipCount set [_x, 0];
            } forEach _sides;

            {
                private _owner = _x getVariable [QEGVAR(Sector,owner), sideUnknown];
                if (_owner in _sides) then {
                    private _cur = _ownershipCount getOrDefault [_owner, 0];
                    _ownershipCount set [_owner, _cur + 1];
                };
            } forEach _sectorList;

            // Determine if any side is being bled (holds <= 1 sector
            // while the other side holds nearly everything)
            private _bleedingSide = sideUnknown;
            private _dominantSide = sideUnknown;

            {
                private _thisSide = _x;
                private _thisCount = _ownershipCount getOrDefault [_thisSide, 0];

                if (_thisCount <= 1) then {
                    // Check if the opposing side is dominant
                    {
                        if (!(_x isEqualTo _thisSide)) then {
                            private _otherCount = _ownershipCount getOrDefault [_x, 0];
                            if (_otherCount >= (_totalSectors - 1)) then {
                                _bleedingSide = _thisSide;
                                _dominantSide = _x;
                            };
                        };
                    } forEach _sides;
                };
            } forEach _sides;

            // Manage the bleed PFH
            if (!(_bleedingSide isEqualTo sideUnknown) && {GVAR(bleedPFH) isEqualTo -1}) then {
                // Start draining the losing side
                GVAR(bleedTargetSide) = _bleedingSide;

                GVAR(bleedPFH) = [{
                    private _targetSide = GVAR(bleedTargetSide);
                    private _varName = format [QGVAR(count_%1), _targetSide];
                    private _current = missionNamespace getVariable [_varName, 0];

                    if (_current > 0) then {
                        [_targetSide, -(GVAR(ticketBleedAmount))] call FUNC(modify);
                    };
                }, GVAR(ticketBleedInterval), []] call PRA3_fw_addPFH;

                diag_log format [
                    "[PRA3 Tickets] Bleed started against %1 (dominant: %2)",
                    _bleedingSide, _dominantSide
                ];

            } else {
                if (_bleedingSide isEqualTo sideUnknown && {!(GVAR(bleedPFH) isEqualTo -1)}) then {
                    // Sector balance restored -- stop the bleed
                    [GVAR(bleedPFH)] call PRA3_fw_removePFH;
                    GVAR(bleedPFH) = -1;
                    GVAR(bleedTargetSide) = sideUnknown;

                    diag_log "[PRA3 Tickets] Bleed stopped -- sector balance restored.";
                };
            };
        };

        // --------------------------------------------------------------
        // 3d. End-of-round detection (dedicated server)
        // --------------------------------------------------------------
        ["ticketsChanged", {
            params ["_changedSide", "_newCount"];

            if (!isDedicated) exitWith {};

            if (_newCount <= 0) then {
                diag_log format [
                    "[PRA3 Tickets] %1 has reached 0 tickets. Ending mission.",
                    _changedSide
                ];
                "END1" call BIS_fnc_endMission;
            };
        }] call PRA3_fw_addHandler;

    }; // end isServer

    // ==================================================================
    // 4. Client-side: HUD and end-game presentation
    // ==================================================================
    if (hasInterface) then {

        // Create the ticket status HUD via cutRsc
        GVAR(hudCreated) = false;

        [{
            !isNull player && {alive player}
        }, {
            // Display the ticket overlay
            UIVAR(TicketStatus) cutRsc [UIVAR(TicketStatus), "PLAIN", -1, false];
            GVAR(hudCreated) = true;

            // Populate initial values
            [] call GVAR(refreshHUD);

            diag_log "[PRA3 Tickets] Client: HUD created.";
        }] call PRA3_fw_waitUntilExec;

        // ----------------------------------------------------------
        // 4a. HUD refresh function
        // ----------------------------------------------------------
        GVAR(refreshHUD) = {
            private _sides = EGVAR(Common,competingSides);
            if (count _sides < 2) exitWith {};

            private _sideA = _sides select 0;
            private _sideB = _sides select 1;

            private _countA = missionNamespace getVariable [
                format [QGVAR(count_%1), _sideA], 0
            ];
            private _countB = missionNamespace getVariable [
                format [QGVAR(count_%1), _sideB], 0
            ];

            // Determine which display side corresponds to the player
            private _playerSide = side group player;
            private _leftSide   = _sideA;
            private _rightSide  = _sideB;
            private _leftCount  = _countA;
            private _rightCount = _countB;

            // Always show the player's side on the left
            if (_playerSide isEqualTo _sideB) then {
                _leftSide   = _sideB;
                _rightSide  = _sideA;
                _leftCount  = _countB;
                _rightCount = _countA;
            };

            // Side background controls
            private _display = uiNamespace getVariable [UIVAR(TicketStatus), displayNull];
            if (isNull _display) exitWith {};

            // Left side (player's side): IDCs 2010-2013
            private _ctrlLeftBg    = _display displayCtrl 2010;
            private _ctrlLeftFlag  = _display displayCtrl 2011;
            private _ctrlLeftName  = _display displayCtrl 2012;
            private _ctrlLeftCount = _display displayCtrl 2013;

            // Right side (opponent): IDCs 2020-2023
            private _ctrlRightBg    = _display displayCtrl 2020;
            private _ctrlRightFlag  = _display displayCtrl 2021;
            private _ctrlRightName  = _display displayCtrl 2022;
            private _ctrlRightCount = _display displayCtrl 2023;

            // Set side names
            _ctrlLeftName  ctrlSetText (str _leftSide);
            _ctrlRightName ctrlSetText (str _rightSide);

            // Set ticket count text
            _ctrlLeftCount  ctrlSetText (str _leftCount);
            _ctrlRightCount ctrlSetText (str _rightCount);

            // Colour the backgrounds based on side
            private _leftColor  = [_leftSide] call GVAR(sideToColor);
            private _rightColor = [_rightSide] call GVAR(sideToColor);

            _ctrlLeftBg  ctrlSetBackgroundColor _leftColor;
            _ctrlRightBg ctrlSetBackgroundColor _rightColor;

            // Set flag icons
            _ctrlLeftFlag  ctrlSetText ([_leftSide] call GVAR(sideToFlag));
            _ctrlRightFlag ctrlSetText ([_rightSide] call GVAR(sideToFlag));
        };

        // ----------------------------------------------------------
        // 4b. Side-to-colour helper
        // ----------------------------------------------------------
        GVAR(sideToColor) = {
            params ["_side"];
            switch (_side) do {
                case west:        { [0.1, 0.2, 0.6, 0.7] };
                case east:        { [0.6, 0.1, 0.1, 0.7] };
                case independent: { [0.1, 0.5, 0.1, 0.7] };
                default           { [0.3, 0.3, 0.3, 0.7] };
            };
        };

        // ----------------------------------------------------------
        // 4c. Side-to-flag icon helper
        // ----------------------------------------------------------
        GVAR(sideToFlag) = {
            params ["_side"];
            switch (_side) do {
                case west:        { "\A3\Data_F\Flags\Flag_nato_CO.paa" };
                case east:        { "\A3\Data_F\Flags\Flag_CSAT_CO.paa" };
                case independent: { "\A3\Data_F\Flags\Flag_AAF_CO.paa" };
                default           { "\A3\Data_F\Flags\Flag_white_CO.paa" };
            };
        };

        // ----------------------------------------------------------
        // 4d. Listen for ticket changes and update HUD
        // ----------------------------------------------------------
        ["ticketsChanged", {
            params ["_changedSide", "_newCount"];

            if (GVAR(hudCreated)) then {
                [] call GVAR(refreshHUD);
            };

            // Check for music threshold
            private _playerSide = side group player;
            private _playerVarName = format [QGVAR(count_%1), _playerSide];
            private _playerTickets = missionNamespace getVariable [_playerVarName, 0];

            if (_playerTickets <= GVAR(musicStartThreshold) &&
                {_playerTickets > 0} &&
                {!GVAR(endMusicPlaying)}) then {

                GVAR(endMusicPlaying) = true;
                ["playEndMusic", [_playerSide]] call PRA3_fw_fireEvent;

                // Start cycling random music tracks from config
                private _musicTracks = getArray (
                    missionConfigFile >> "PRA3" >> "CfgMusic" >> "endTracks"
                );
                if (count _musicTracks > 0) then {
                    private _track = selectRandom _musicTracks;
                    playMusic _track;

                    diag_log format [
                        "[PRA3 Tickets] End music started: %1", _track
                    ];
                };
            };

            // Check for game-over state on client
            if (_newCount <= 0) then {
                private _playerSide = side group player;

                if (_changedSide isEqualTo _playerSide) then {
                    // Player's side ran out -- show LOSER screen
                    UIVAR(TicketEndScreen) cutRsc [UIVAR(TicketEndScreen), "PLAIN", -1, false];
                    private _endDisplay = uiNamespace getVariable [
                        UIVAR(TicketEndScreen), displayNull
                    ];
                    if (!isNull _endDisplay) then {
                        private _ctrlTitle = _endDisplay displayCtrl 3001;
                        _ctrlTitle ctrlSetText "DEFEAT";
                        _ctrlTitle ctrlSetTextColor [0.8, 0.1, 0.1, 1.0];
                    };
                } else {
                    // Opposing side ran out -- show WINNER screen
                    UIVAR(TicketEndScreen) cutRsc [UIVAR(TicketEndScreen), "PLAIN", -1, false];
                    private _endDisplay = uiNamespace getVariable [
                        UIVAR(TicketEndScreen), displayNull
                    ];
                    if (!isNull _endDisplay) then {
                        private _ctrlTitle = _endDisplay displayCtrl 3001;
                        _ctrlTitle ctrlSetText "VICTORY";
                        _ctrlTitle ctrlSetTextColor [0.1, 0.7, 0.1, 1.0];
                    };
                };
            };
        }] call PRA3_fw_addHandler;

        // ----------------------------------------------------------
        // 4e. Sector enter/leave: animate ticket HUD position
        //     Shift it upward to make room for the capture progress bar
        // ----------------------------------------------------------
        ["sectorEntered", {
            params ["_unit", "_sector"];

            if (!(_unit isEqualTo player)) exitWith {};

            private _display = uiNamespace getVariable [UIVAR(TicketStatus), displayNull];
            if (isNull _display) exitWith {};

            // Shift the ticket status display upward
            private _ctrlLeftBg = _display displayCtrl 2010;
            private _ctrlRightBg = _display displayCtrl 2020;

            private _posL = ctrlPosition _ctrlLeftBg;
            private _posR = ctrlPosition _ctrlRightBg;

            // Move up by PY(2) to clear the capture bar
            private _shiftAmount = PY(2);

            _ctrlLeftBg ctrlSetPosition [
                _posL select 0,
                (_posL select 1) - _shiftAmount,
                _posL select 2,
                _posL select 3
            ];
            _ctrlRightBg ctrlSetPosition [
                _posR select 0,
                (_posR select 1) - _shiftAmount,
                _posR select 2,
                _posR select 3
            ];

            _ctrlLeftBg  ctrlCommit 0.3;
            _ctrlRightBg ctrlCommit 0.3;
        }] call PRA3_fw_addHandler;

        ["sectorLeft", {
            params ["_unit", "_sector"];

            if (!(_unit isEqualTo player)) exitWith {};

            private _display = uiNamespace getVariable [UIVAR(TicketStatus), displayNull];
            if (isNull _display) exitWith {};

            // Restore the ticket status display to original position
            private _ctrlLeftBg = _display displayCtrl 2010;
            private _ctrlRightBg = _display displayCtrl 2020;

            private _posL = ctrlPosition _ctrlLeftBg;
            private _posR = ctrlPosition _ctrlRightBg;

            private _shiftAmount = PY(2);

            _ctrlLeftBg ctrlSetPosition [
                _posL select 0,
                (_posL select 1) + _shiftAmount,
                _posL select 2,
                _posL select 3
            ];
            _ctrlRightBg ctrlSetPosition [
                _posR select 0,
                (_posR select 1) + _shiftAmount,
                _posR select 2,
                _posR select 3
            ];

            _ctrlLeftBg  ctrlCommit 0.3;
            _ctrlRightBg ctrlCommit 0.3;
        }] call PRA3_fw_addHandler;

    }; // end hasInterface

    diag_log "[PRA3 Tickets] Init complete on this machine.";

}] call PRA3_fw_waitUntilExec;

diag_log "[PRA3 Tickets] Init started, waiting for competing sides.";
