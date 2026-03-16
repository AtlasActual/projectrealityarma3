#include "script_component.hpp"
/*
    FUNC(animateControl)

    Description:
        UI animation utility that slides a control from off-screen to its
        intended position. The control is moved to the nearest screen edge
        (left or right) based on its horizontal center, then smoothly
        animated back to its original position over the given duration.

    Parameters:
        0: _control  - CONTROL - the UI control to animate
        1: _duration - NUMBER  - (optional) animation duration in seconds
                       default: 0.5

    Returns:
        Nothing
*/

params ["_control", ["_duration", 0.5]];

// Record the final intended position before moving the control away
private _targetPos = ctrlPosition _control;
private _ctrlWidth = _targetPos select 2;
private _ctrlCenterX = (_targetPos select 0) + (_ctrlWidth / 2);

// Determine which edge is closer: left (safeZoneX) or right (safeZoneX + safeZoneW)
// Place the control just beyond that edge so it is fully off-screen
private _offScreenX = if (_ctrlCenterX > 0.5) then {
    // Closer to the right edge: slide in from the right
    safeZoneX + safeZoneW
} else {
    // Closer to the left edge: slide in from the left
    safeZoneX - _ctrlWidth
};

// Move the control to its off-screen starting position
_control ctrlSetPosition [
    _offScreenX,
    _targetPos select 1,
    _targetPos select 2,
    _targetPos select 3
];
_control ctrlCommit 0;

// Wait one frame for the initial placement to take effect, then animate
[{
    params ["_control", "_targetPos", "_duration"];

    _control ctrlSetPosition _targetPos;
    _control ctrlSetFade 0;
    _control ctrlCommit _duration;
}, [_control, _targetPos, _duration]] call PRA3_fw_execNextFrame;
