#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-side compass rendered via Draw3D. Displays cardinal and
        intercardinal labels, degree ticks, nearby friendly unit direction
        dots, and coloured objective markers placed on a 3D ring around
        the player at each bearing.

    Called once per client during module init.
*/

if (!hasInterface) exitWith {};

// ======================================================================
// 1. Configuration constants
// ======================================================================
GVAR(compassRingDist)    = 80;         // metres – radius of the compass ring
GVAR(compassRingOffset)  = 3;          // metres above camera for compass ring
GVAR(tickSpacing)        = 5;          // degrees between minor ticks
GVAR(unitDotRange)       = 300;        // max range to show friendly dots
GVAR(unitDotMaxCount)    = 16;         // cap for performance

// Line markers hashmap: markerId -> [color, position]
GVAR(lineMarkers) = createHashMap;

// ======================================================================
// 2. Helper: normalize angle to 0..360
// ======================================================================
DFUNC(normalizeAngle) = {
    params ["_angle"];
    private _a = _angle mod 360;
    if (_a < 0) then { _a = _a + 360 };
    _a
};

// ======================================================================
// 3. Main Draw3D handler
// ======================================================================
addMissionEventHandler ["Draw3D", {
    if (isNull player) exitWith {};

    private _camPos   = positionCameraToWorld [0, 0, 0];
    private _camDir   = getCameraViewDirection player;
    private _bearing  = (_camDir select 0) atan2 (_camDir select 1);
    _bearing = [_bearing] call FUNC(normalizeAngle);

    private _ringDist = GVAR(compassRingDist);
    private _ringZ    = (_camPos select 2) + GVAR(compassRingOffset);
    private _cx       = _camPos select 0;
    private _cy       = _camPos select 1;

    // ------------------------------------------------------------------
    // Cardinal and intercardinal labels
    // ------------------------------------------------------------------
    {
        _x params ["_deg", "_label", "_isCardinal"];

        private _pos = [
            _cx + (sin _deg) * _ringDist,
            _cy + (cos _deg) * _ringDist,
            _ringZ
        ];

        private _textSize = if (_isCardinal) then { 0.045 } else { 0.035 };
        private _color    = if (_isCardinal) then { [1, 1, 1, 1] } else { [0.85, 0.85, 0.85, 0.8] };

        // Label text
        drawIcon3D ["", _color, _pos, 0, 0, 0, _label, 2, _textSize, "PuristaMedium"];

        // Tick line
        private _tickH = if (_isCardinal) then { 0.8 } else { 0.5 };
        drawLine3D [
            [_pos select 0, _pos select 1, _ringZ - _tickH * 0.5],
            [_pos select 0, _pos select 1, _ringZ + _tickH * 0.5],
            _color
        ];
    } forEach [
        [0,   "N",  true],  [45,  "NE", false],
        [90,  "E",  true],  [135, "SE", false],
        [180, "S",  true],  [225, "SW", false],
        [270, "W",  true],  [315, "NW", false]
    ];

    // ------------------------------------------------------------------
    // Minor ticks every tickSpacing degrees, degree numbers every 15
    // ------------------------------------------------------------------
    for "_deg" from 0 to 355 step GVAR(tickSpacing) do {
        // Skip cardinal/intercardinal degrees (already drawn above)
        if (_deg mod 45 == 0) then { continue };

        private _isMajor = (_deg mod 15 == 0);
        private _tickH   = if (_isMajor) then { 0.4 } else { 0.25 };

        private _px = _cx + (sin _deg) * _ringDist;
        private _py = _cy + (cos _deg) * _ringDist;

        drawLine3D [
            [_px, _py, _ringZ - _tickH * 0.5],
            [_px, _py, _ringZ + _tickH * 0.5],
            [0.7, 0.7, 0.7, 0.4]
        ];

        // Degree number on major ticks
        if (_isMajor) then {
            drawIcon3D [
                "", [0.7, 0.7, 0.7, 0.5],
                [_px, _py, _ringZ],
                0, 0, 0,
                str _deg, 2, 0.028, "PuristaMedium"
            ];
        };
    };

    // ------------------------------------------------------------------
    // Centre bearing readout – placed at the bearing the camera faces
    // ------------------------------------------------------------------
    private _fwdPos = [
        _cx + (sin _bearing) * _ringDist,
        _cy + (cos _bearing) * _ringDist,
        _ringZ - 1.2
    ];
    drawIcon3D [
        "", [1, 0.85, 0.2, 0.95],
        _fwdPos,
        0, 0, 0,
        str (round _bearing), 2, 0.04, "PuristaMedium"
    ];

    // ------------------------------------------------------------------
    // Friendly unit direction dots
    // ------------------------------------------------------------------
    private _playerPos  = getPosATL player;
    private _playerSide = side group player;
    private _processed  = 0;

    {
        if (_processed >= GVAR(unitDotMaxCount)) then { break };
        if (_x isEqualTo player) then { continue };
        if (!alive _x) then { continue };
        if (side group _x isNotEqualTo _playerSide) then { continue };

        private _unitPos = getPosATL _x;
        private _dist    = _playerPos distance2D _unitPos;
        if (_dist > GVAR(unitDotRange) || _dist < 1) then { continue };

        private _dx = (_unitPos select 0) - (_playerPos select 0);
        private _dy = (_unitPos select 1) - (_playerPos select 1);
        private _unitBearing = [_dx atan2 _dy] call FUNC(normalizeAngle);

        private _dotPos = [
            _cx + (sin _unitBearing) * _ringDist,
            _cy + (cos _unitBearing) * _ringDist,
            _ringZ - 0.8
        ];

        private _alpha = linearConversion [50, GVAR(unitDotRange), _dist, 1.0, 0.3, true];
        private _isSqd = group _x isEqualTo group player;
        private _dotClr = if (_isSqd) then {
            [0.2, 1, 0.3, _alpha]
        } else {
            [0.5, 0.75, 1, _alpha * 0.65]
        };

        drawIcon3D [
            "\a3\ui_f\data\map\markers\military\dot_ca.paa",
            _dotClr, _dotPos,
            0.5, 0.5, 0, "", 0
        ];

        _processed = _processed + 1;
    } forEach allUnits;

    // ------------------------------------------------------------------
    // Objective line markers
    // ------------------------------------------------------------------
    {
        if (isNil "_y") then { continue };
        _y params ["_mColor", "_mPos"];

        private _dx = (_mPos select 0) - (_playerPos select 0);
        private _dy = (_mPos select 1) - (_playerPos select 1);
        private _objBearing = [_dx atan2 _dy] call FUNC(normalizeAngle);

        private _mx = _cx + (sin _objBearing) * _ringDist;
        private _my = _cy + (cos _objBearing) * _ringDist;

        drawLine3D [
            [_mx, _my, _ringZ - 0.5],
            [_mx, _my, _ringZ + 0.5],
            _mColor
        ];

        drawIcon3D [
            "\a3\ui_f\data\map\markers\military\diamond_ca.paa",
            _mColor,
            [_mx, _my, _ringZ - 0.7],
            0.6, 0.6, 0, "", 0
        ];
    } forEach GVAR(lineMarkers);
}];

diag_log "[PRA3 CompassUI] Client compass HUD active.";
