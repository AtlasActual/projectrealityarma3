#include "script_component.hpp"
/*
    FUNC(bloodScreen)

    Description:
        Displays a post-process blood splatter effect on the screen when
        the player takes damage. Uses color correction PP to tint the
        screen red with intensity proportional to damage taken. The
        effect fades out over approximately 2 seconds.

    Params:
        0: _intensity - NUMBER - damage intensity (0.0 to 1.0)

    Returns: nothing
*/

params [["_intensity", 0.5]];

if (!hasInterface) exitWith {};

// Clamp intensity range
_intensity = _intensity max 0.0 min 1.0;

// Create a temporary color correction post-process
private _ppHandle = ppEffectCreate ["ColorCorrections", 1600];
_ppHandle ppEffectEnable true;

// Apply red tint with intensity-based strength
// ColorCorrections params: [brightness, contrast, offset, blend, [r,g,b,a], [r2,g2,b2,a2]]
private _blendAlpha = _intensity * 0.6;
_ppHandle ppEffectAdjust [
    1.0, 1.0, 0.0,
    [0.0, 0.0, 0.0, 0.0],
    [_blendAlpha * 0.8, 0.0, 0.0, _blendAlpha],
    [1.0, 0.3, 0.3, 0.0]
];
_ppHandle ppEffectCommit 0;

// Fade out over 2 seconds
[{
    params ["_ppHandle"];
    _ppHandle ppEffectAdjust [
        1.0, 1.0, 0.0,
        [0.0, 0.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 0.0],
        [1.0, 1.0, 1.0, 0.0]
    ];
    _ppHandle ppEffectCommit 2.0;

    // Schedule cleanup after the commit finishes
    [{
        params ["_ppHandle"];
        ppEffectDestroy _ppHandle;
    }, [_ppHandle], 2.2] call CBA_fnc_waitAndExecute;

}, [_ppHandle], 0.05] call CBA_fnc_waitAndExecute;
