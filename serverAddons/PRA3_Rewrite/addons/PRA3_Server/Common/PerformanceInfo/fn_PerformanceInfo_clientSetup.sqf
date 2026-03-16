#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-side performance monitoring. Adds a per-second handler
        that checks the local frame rate and, when it drops below 15 FPS,
        displays a prominent warning indicator on screen.

        When the mod is compiled in dev mode (isDev defined) an
        additional live FPS graph is rendered via the Draw3D mission
        event handler using colour-coded bars:
            green  - 30+ FPS
            yellow - 15-29 FPS
            red    - below 15 FPS

    Called once per client during module init.
*/

if (!hasInterface) exitWith {};

// Rolling buffer for the dev-mode graph (last 60 samples)
GVAR(fpsHistory) = [];
GVAR(maxSamples) = 60;

// Low-FPS warning state
GVAR(warningActive) = false;

// Server FPS received via global event
GVAR(serverFPS) = -1;

// Listen for server FPS broadcasts
["serverFPS", {
    params ["_fps"];
    GVAR(serverFPS) = _fps;
}] call PRA3_fw_addHandler;

// ---- Per-second sampling PFH ----
[{
    private _fps = diag_fps;

    // Maintain rolling history buffer
    GVAR(fpsHistory) pushBack _fps;
    if (count GVAR(fpsHistory) > GVAR(maxSamples)) then {
        GVAR(fpsHistory) deleteAt 0;
    };

    // ---- Low-FPS warning ----
    private _display = findDisplay 46;
    if (isNull _display) exitWith {};

    if (_fps < 15) then {
        if (!GVAR(warningActive)) then {
            GVAR(warningActive) = true;

            // Create warning controls if they do not already exist
            private _ctrlBG = _display displayCtrl 4100;
            if (isNull _ctrlBG) then {
                _ctrlBG = _display ctrlCreate ["RscText", 4100];
            };
            _ctrlBG ctrlSetBackgroundColor [0.7, 0.1, 0.1, 0.75];
            _ctrlBG ctrlSetPosition [
                safezoneX + safezoneW - PX(6),
                safezoneY + PY(0.5),
                PX(5.5),
                PY(1)
            ];
            _ctrlBG ctrlCommit 0;

            private _ctrlTxt = _display displayCtrl 4101;
            if (isNull _ctrlTxt) then {
                _ctrlTxt = _display ctrlCreate ["RscStructuredText", 4101];
            };
            _ctrlTxt ctrlSetStructuredText parseText format [
                "<t align='center' color='#ffffff' size='0.9'>LOW FPS: %1</t>",
                round _fps
            ];
            _ctrlTxt ctrlSetPosition [
                safezoneX + safezoneW - PX(6),
                safezoneY + PY(0.5),
                PX(5.5),
                PY(1)
            ];
            _ctrlTxt ctrlCommit 0;
        } else {
            // Just refresh the number
            private _ctrlTxt = _display displayCtrl 4101;
            if (!isNull _ctrlTxt) then {
                _ctrlTxt ctrlSetStructuredText parseText format [
                    "<t align='center' color='#ffffff' size='0.9'>LOW FPS: %1</t>",
                    round _fps
                ];
            };
        };
    } else {
        if (GVAR(warningActive)) then {
            GVAR(warningActive) = false;
            ctrlDelete (_display displayCtrl 4100);
            ctrlDelete (_display displayCtrl 4101);
        };
    };

}, 1] call PRA3_fw_addPFH;

// ---- Dev-mode FPS graph (Draw3D overlay) ----
#ifdef isDev

GVAR(graphControls) = [];

[{
    disableSerialization;

    private _display = findDisplay 46;
    if (isNull _display) exitWith {};

    // Clean up previous frame's bar controls
    {
        ctrlDelete _x;
    } forEach GVAR(graphControls);
    GVAR(graphControls) = [];

    private _history  = GVAR(fpsHistory);
    private _count    = count _history;
    if (_count == 0) exitWith {};

    // Graph area: bottom-right corner of screen
    private _graphX   = safezoneX + safezoneW - PX(14);
    private _graphY   = safezoneY + safezoneH - PY(6);
    private _graphW   = PX(13);
    private _graphH   = PY(5);

    private _barWidth = _graphW / GVAR(maxSamples);
    private _maxFPS   = 60;

    // Background
    private _bg = _display ctrlCreate ["RscText", -1];
    _bg ctrlSetBackgroundColor [0, 0, 0, 0.45];
    _bg ctrlSetPosition [_graphX - PX(0.2), _graphY - PY(0.2), _graphW + PX(0.4), _graphH + PY(0.7)];
    _bg ctrlCommit 0;
    GVAR(graphControls) pushBack _bg;

    // Label
    private _label = _display ctrlCreate ["RscStructuredText", -1];
    private _svrText = if (GVAR(serverFPS) > 0) then {
        format [" | Server: %1", round GVAR(serverFPS)]
    } else {
        ""
    };
    _label ctrlSetStructuredText parseText format [
        "<t color='#cccccc' size='0.7'>Client: %1 FPS%2</t>",
        round diag_fps,
        _svrText
    ];
    _label ctrlSetPosition [_graphX, _graphY + _graphH, _graphW, PY(0.5)];
    _label ctrlCommit 0;
    GVAR(graphControls) pushBack _label;

    // Draw each bar
    {
        private _fpsVal   = _x;
        private _barIdx   = _forEachIndex;
        private _ratio    = (_fpsVal / _maxFPS) min 1;
        private _barH     = _graphH * _ratio;
        private _barY     = _graphY + _graphH - _barH;
        private _barX     = _graphX + _barIdx * _barWidth;

        // Colour thresholds
        private _barColor = if (_fpsVal >= 30) then {
            [0.2, 0.8, 0.2, 0.9]   // green
        } else {
            if (_fpsVal >= 15) then {
                [0.9, 0.8, 0.1, 0.9] // yellow
            } else {
                [0.85, 0.15, 0.15, 0.9] // red
            };
        };

        private _bar = _display ctrlCreate ["RscText", -1];
        _bar ctrlSetBackgroundColor _barColor;
        _bar ctrlSetPosition [_barX, _barY, _barWidth * 0.85, _barH];
        _bar ctrlCommit 0;

        GVAR(graphControls) pushBack _bar;
    } forEach _history;

}, 0] call PRA3_fw_addPFH;

#endif

diag_log "[PRA3 PerformanceInfo] Client performance monitor active.";
