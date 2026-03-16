#include "script_component.hpp"
/*
    FUNC(processQueue)

    Description:
        Dequeues and displays the highest-priority notification from
        GVAR(queue). The notification bar slides in from above the
        screen, stays visible for the configured duration, then slides
        back out. When the animation finishes a "notificationDone" event
        is fired locally and, if more entries remain, the next one is
        scheduled after a short gap.

        UI control IDCs used:
            4000 - background panel
            4001 - text label
            4002 - coloured accent stripe

    Called internally -- never invoke directly.
*/

// Nothing to show
if (GVAR(queue) isEqualTo []) exitWith {
    GVAR(processing) = false;
};

GVAR(processing) = true;

// Pull the front entry (highest priority after sort)
private _entry = GVAR(queue) deleteAt 0;
_entry params ["_text", "_color", "_duration", "_priority", "_conditionCode"];

// Evaluate the condition -- skip this entry when it returns false
if !([] call _conditionCode) exitWith {
    // Try the next entry immediately
    [] call FUNC(processQueue);
};

// ---- Obtain display and controls ----
private _display = findDisplay 46;
if (isNull _display) exitWith {
    GVAR(processing) = false;
};

private _ctrlBG     = _display displayCtrl 4000;
private _ctrlText   = _display displayCtrl 4001;
private _ctrlAccent = _display displayCtrl 4002;

// ---- Configure control content ----
_ctrlBG ctrlSetBackgroundColor _color;
_ctrlText ctrlSetText _text;
_ctrlAccent ctrlSetBackgroundColor [0.85, 0.65, 0.13, 1];

// ---- Slide-in animation (from above screen) ----
private _barHeight = PY(1.4);
private _startY    = safezoneY - _barHeight;
private _endY      = safezoneY;
private _barWidth  = safezoneW * 0.35;
private _barX      = safezoneX + (safezoneW - _barWidth) / 2;

// Position off-screen first
_ctrlBG ctrlSetPosition [_barX, _startY, _barWidth, _barHeight];
_ctrlBG ctrlCommit 0;

_ctrlText ctrlSetPosition [_barX + PX(0.3), _startY, _barWidth - PX(0.6), _barHeight];
_ctrlText ctrlCommit 0;

_ctrlAccent ctrlSetPosition [_barX, _startY + _barHeight - PY(0.08), _barWidth, PY(0.08)];
_ctrlAccent ctrlCommit 0;

// Animate to on-screen position
_ctrlBG ctrlSetPosition [_barX, _endY, _barWidth, _barHeight];
_ctrlBG ctrlCommit 0.25;

_ctrlText ctrlSetPosition [_barX + PX(0.3), _endY, _barWidth - PX(0.6), _barHeight];
_ctrlText ctrlCommit 0.25;

_ctrlAccent ctrlSetPosition [_barX, _endY + _barHeight - PY(0.08), _barWidth, PY(0.08)];
_ctrlAccent ctrlCommit 0.25;

// ---- Hold, then slide out ----
[{
    params ["_ctrlBG", "_ctrlText", "_ctrlAccent", "_startY", "_barX", "_barWidth", "_barHeight"];

    // Slide controls back above the screen
    _ctrlBG ctrlSetPosition [_barX, _startY, _barWidth, _barHeight];
    _ctrlBG ctrlCommit 0.25;

    _ctrlText ctrlSetPosition [_barX + PX(0.3), _startY, _barWidth - PX(0.6), _barHeight];
    _ctrlText ctrlCommit 0.25;

    _ctrlAccent ctrlSetPosition [_barX, _startY + _barHeight - PY(0.08), _barWidth, PY(0.08)];
    _ctrlAccent ctrlCommit 0.25;

    // After slide-out completes, fire event and continue queue
    [{
        ["notificationDone", []] call PRA3_fw_fireEvent;

        // Brief pause before showing next notification
        if !(GVAR(queue) isEqualTo []) then {
            [{
                [] call FUNC(processQueue);
            }, 0.35] call PRA3_fw_waitAndExec;
        } else {
            GVAR(processing) = false;
        };
    }, 0.3] call PRA3_fw_waitAndExec;

}, _duration + 0.3, [_ctrlBG, _ctrlText, _ctrlAccent, _startY, _barX, _barWidth, _barHeight]] call PRA3_fw_waitAndExec;
