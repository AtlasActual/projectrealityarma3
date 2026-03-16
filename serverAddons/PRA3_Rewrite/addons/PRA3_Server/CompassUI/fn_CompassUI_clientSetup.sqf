#include "script_component.hpp"
/*
    FUNC(clientSetup)

    Description:
        Client-side compass HUD rendered via Draw3D. Displays a horizontal
        bearing strip at the top of the screen with cardinal/intercardinal
        labels, degree ticks, nearby friendly unit direction indicators,
        and coloured objective line markers.

    Called once per client during module init.
*/

if (!hasInterface) exitWith {};

// ======================================================================
// 1. Configuration constants
// ======================================================================
GVAR(compassFieldOfView) = 180;        // degrees visible on the strip
GVAR(compassYPosition)   = 0.04;       // vertical screen fraction from top
GVAR(tickSpacing)        = 5;          // degrees between minor ticks
GVAR(unitDotRange)       = 300;        // max range to show friendly dots
GVAR(unitDotMaxCount)    = 16;         // cap for performance

// Line markers hashmap: markerId -> [color, position]
GVAR(lineMarkers) = createHashMap;

// ======================================================================
// 2. Cardinal direction labels
// ======================================================================
GVAR(cardinalLabels) = createHashMap;
GVAR(cardinalLabels) set [0,   "N"];
GVAR(cardinalLabels) set [45,  "NE"];
GVAR(cardinalLabels) set [90,  "E"];
GVAR(cardinalLabels) set [135, "SE"];
GVAR(cardinalLabels) set [180, "S"];
GVAR(cardinalLabels) set [225, "SW"];
GVAR(cardinalLabels) set [270, "W"];
GVAR(cardinalLabels) set [315, "NW"];

// ======================================================================
// 3. Helper: normalize angle to 0..360
// ======================================================================
DFUNC(normalizeAngle) = {
    params ["_angle"];
    private _a = _angle mod 360;
    if (_a < 0) then { _a = _a + 360 };
    _a
};

// ======================================================================
// 4. Helper: angular difference clamped to -180..180
// ======================================================================
DFUNC(angleDiff) = {
    params ["_from", "_to"];
    private _d = _to - _from;
    if (_d > 180)  then { _d = _d - 360 };
    if (_d < -180) then { _d = _d + 360 };
    _d
};

// ======================================================================
// 5. Helper: bearing difference to screen X fraction (0..1)
// ======================================================================
DFUNC(bearingToScreenX) = {
    params ["_playerBearing", "_targetBearing"];
    private _diff = [_playerBearing, _targetBearing] call FUNC(angleDiff);
    private _halfFov = GVAR(compassFieldOfView) / 2;
    // Map from -halfFov..+halfFov to 0..1
    private _frac = 0.5 + (_diff / (2 * _halfFov));
    _frac
};

// ======================================================================
// 6. Helper: alpha from screen-edge proximity (fade at edges)
// ======================================================================
DFUNC(edgeAlpha) = {
    params ["_screenX"];
    // Fade within the outer 15% on each side
    private _edgeZone = 0.15;
    private _a = 1.0;
    if (_screenX < _edgeZone) then {
        _a = linearConversion [0, _edgeZone, _screenX, 0, 1, true];
    };
    if (_screenX > (1 - _edgeZone)) then {
        _a = linearConversion [1 - _edgeZone, 1, _screenX, 1, 0, true];
    };
    _a
};

// ======================================================================
// 7. Main Draw3D handler
// ======================================================================
addMissionEventHandler ["Draw3D", {
    if (isNull player) exitWith {};

    private _camDir   = getCameraViewDirection player;
    private _bearing  = (_camDir select 0) atan2 (_camDir select 1);
    _bearing = [_bearing] call FUNC(normalizeAngle);

    private _halfFov  = GVAR(compassFieldOfView) / 2;
    private _yPos     = GVAR(compassYPosition);

    // Determine the range of degrees visible
    private _minBearing = _bearing - _halfFov;
    private _maxBearing = _bearing + _halfFov;

    // Screen dimensions for positioning
    private _szX = safeZoneX;
    private _szW = safeZoneW;
    private _szY = safeZoneY;

    // ------------------------------------------------------------------
    // 7a. Draw the semi-transparent backdrop strip
    // ------------------------------------------------------------------
    private _barLeft   = _szX;
    private _barRight  = _szX + _szW;
    private _barTop    = _szY + PY(_yPos);
    private _barHeight = PY(0.6);

    drawRectangle [
        [_barLeft + _szW * 0.5, _barTop + _barHeight * 0.5],
        _szW * 0.5,
        _barHeight * 0.5,
        0,
        [0, 0, 0, 0.35],
        true
    ];

    // ------------------------------------------------------------------
    // 7b. Draw bearing ticks and labels
    // ------------------------------------------------------------------
    // Iterate over every tick degree in the visible range
    private _startDeg = floor (_minBearing / GVAR(tickSpacing)) * GVAR(tickSpacing);
    private _endDeg   = ceil (_maxBearing / GVAR(tickSpacing)) * GVAR(tickSpacing);

    for "_deg" from _startDeg to _endDeg step GVAR(tickSpacing) do {
        private _normDeg = [_deg] call FUNC(normalizeAngle);
        private _sx = [_bearing, _deg] call FUNC(bearingToScreenX);

        if (_sx < 0 || _sx > 1) then { continue };

        private _alpha = [_sx] call FUNC(edgeAlpha);
        private _screenPosX = _szX + _szW * _sx;
        private _screenPosY = _szY + PY(_yPos);

        // Cardinal / intercardinal label check
        private _label = GVAR(cardinalLabels) getOrDefault [_normDeg, ""];

        if (_label isNotEqualTo "") then {
            // Cardinal tick: taller line + text label
            private _isCardinal = _normDeg in [0, 90, 180, 270];
            private _textSize   = if (_isCardinal) then { 0.04 } else { 0.032 };
            private _tickLen    = if (_isCardinal) then { PY(0.35) } else { PY(0.25) };
            private _textColor  = if (_isCardinal) then {
                [1, 1, 1, _alpha]
            } else {
                [0.85, 0.85, 0.85, _alpha * 0.8]
            };

            // Vertical tick line
            drawLine2D [
                [_screenPosX, _screenPosY],
                [_screenPosX, _screenPosY + _tickLen],
                [1, 1, 1, _alpha * 0.6],
                1
            ];

            // Label text above the tick
            drawIcon2D [
                "",
                _textColor,
                [_screenPosX, _screenPosY + PY(0.4)],
                0, 0, 0,
                _label,
                2,
                _textSize,
                "PuristaMedium",
                "center"
            ];
        } else {
            // Minor tick: short mark
            private _degRound = round _normDeg;
            private _isMajor  = (_degRound mod 15 == 0);
            private _tickLen  = if (_isMajor) then { PY(0.2) } else { PY(0.12) };

            drawLine2D [
                [_screenPosX, _screenPosY],
                [_screenPosX, _screenPosY + _tickLen],
                [0.7, 0.7, 0.7, _alpha * 0.4],
                1
            ];

            // Show degree number on major ticks (every 15 degrees)
            if (_isMajor) then {
                drawIcon2D [
                    "",
                    [0.7, 0.7, 0.7, _alpha * 0.5],
                    [_screenPosX, _screenPosY + PY(0.35)],
                    0, 0, 0,
                    str _normDeg,
                    2,
                    0.026,
                    "PuristaMedium",
                    "center"
                ];
            };
        };
    };

    // ------------------------------------------------------------------
    // 7c. Centre bearing indicator (small triangle/line at the centre)
    // ------------------------------------------------------------------
    private _centreX = _szX + _szW * 0.5;
    drawLine2D [
        [_centreX, _szY + PY(_yPos) - PY(0.08)],
        [_centreX, _szY + PY(_yPos) + PY(0.08)],
        [1, 0.8, 0, 0.9],
        2
    ];

    // Numerical bearing readout at centre
    drawIcon2D [
        "",
        [1, 0.85, 0.2, 0.95],
        [_centreX, _szY + PY(_yPos) - PY(0.18)],
        0, 0, 0,
        str (round _bearing),
        2,
        0.032,
        "PuristaMedium",
        "center"
    ];

    // ------------------------------------------------------------------
    // 7d. Friendly unit direction dots
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

        // Bearing from player to this unit
        private _dx = (_unitPos select 0) - (_playerPos select 0);
        private _dy = (_unitPos select 1) - (_playerPos select 1);
        private _unitBearing = [_dx atan2 _dy] call FUNC(normalizeAngle);

        private _sx = [_bearing, _unitBearing] call FUNC(bearingToScreenX);
        if (_sx < 0 || _sx > 1) then { continue };

        private _alpha = [_sx] call FUNC(edgeAlpha);
        // Distance-based alpha reduction
        _alpha = _alpha * linearConversion [50, GVAR(unitDotRange), _dist, 1.0, 0.3, true];

        private _dotX   = _szX + _szW * _sx;
        private _dotY   = _szY + PY(_yPos) + PY(0.55);
        private _isSqd  = group _x isEqualTo group player;
        private _dotClr = if (_isSqd) then {
            [0.2, 1, 0.3, _alpha]
        } else {
            [0.5, 0.75, 1, _alpha * 0.65]
        };

        drawIcon2D [
            "\a3\ui_f\data\map\markers\military\dot_ca.paa",
            _dotClr,
            [_dotX, _dotY],
            8, 8,
            0, "", 0
        ];

        _processed = _processed + 1;
    } forEach allUnits;

    // ------------------------------------------------------------------
    // 7e. Objective line markers
    // ------------------------------------------------------------------
    {
        private _markerId = _x;
        private _markerData = _y;

        if (isNil "_markerData") then { continue };

        _markerData params ["_mColor", "_mPos"];

        private _dx = (_mPos select 0) - (_playerPos select 0);
        private _dy = (_mPos select 1) - (_playerPos select 1);
        private _objBearing = [_dx atan2 _dy] call FUNC(normalizeAngle);

        private _sx = [_bearing, _objBearing] call FUNC(bearingToScreenX);
        if (_sx < 0 || _sx > 1) then { continue };

        private _alpha = [_sx] call FUNC(edgeAlpha);
        private _markerScreenX = _szX + _szW * _sx;
        private _markerTopY    = _szY + PY(_yPos);

        // Coloured vertical indicator line spanning the compass bar height
        private _drawColor = +_mColor;
        _drawColor set [3, _alpha * (_drawColor select 3)];

        drawLine2D [
            [_markerScreenX, _markerTopY],
            [_markerScreenX, _markerTopY + PY(0.6)],
            _drawColor,
            2
        ];

        // Small diamond icon at the bottom of the indicator
        drawIcon2D [
            "\a3\ui_f\data\map\markers\military\diamond_ca.paa",
            _drawColor,
            [_markerScreenX, _markerTopY + PY(0.65)],
            10, 10,
            0, "", 0
        ];
    } forEach GVAR(lineMarkers);
}];

diag_log "[PRA3 CompassUI] Client compass HUD active.";
