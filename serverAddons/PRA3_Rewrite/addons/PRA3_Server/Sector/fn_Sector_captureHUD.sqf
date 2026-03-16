#include "script_component.hpp"
/*
    FUNC(captureHUD)

    Description:
        Client-side capture progress HUD. Shows or hides a progress bar
        overlay when the player enters or leaves a contested sector.
        Uses control IDCs:
            1001 - background panel
            1002 - progress bar fill
            1003 - sector name label
            1004 - percentage text

    Params:
        _show   - (Boolean) true to show, false to hide
        _sector - (Object)  the sector logic

    Called from FUNC(clientSetup) enter/leave handling.
*/

params ["_show", "_sector"];

if (!hasInterface) exitWith {};

disableSerialization;

// ======================================================================
// HIDE path
// ======================================================================
if (!_show) exitWith {
    // Stop the interpolation PFH if running
    if (!isNil QGVAR(hudPFH)) then {
        [GVAR(hudPFH)] call PRA3_fw_removePFH;
        GVAR(hudPFH) = nil;
    };

    // Animate out the HUD controls
    private _display = uiNamespace getVariable [UIVAR(SectorHUD), displayNull];
    if (!isNull _display) then {
        private _bg = _display displayCtrl 1001;
        private _bar = _display displayCtrl 1002;
        private _label = _display displayCtrl 1003;
        private _pctText = _display displayCtrl 1004;

        _bg ctrlSetFade 1;
        _bg ctrlCommit 0.3;
        _bar ctrlSetFade 1;
        _bar ctrlCommit 0.3;
        _label ctrlSetFade 1;
        _label ctrlCommit 0.3;
        _pctText ctrlSetFade 1;
        _pctText ctrlCommit 0.3;
    };
};

// ======================================================================
// SHOW path
// ======================================================================
if (isNull _sector) exitWith {};

// Get or create the HUD layer
private _layerId = UIVAR(SectorHUD);
_layerId cutRsc [UIVAR(SectorHUD), "PLAIN", 0.2, true];

private _display = uiNamespace getVariable [UIVAR(SectorHUD), displayNull];
if (isNull _display) exitWith {
    diag_log "[PRA3 Sector] WARNING: Could not create capture HUD display.";
};

private _bg      = _display displayCtrl 1001;
private _bar     = _display displayCtrl 1002;
private _label   = _display displayCtrl 1003;
private _pctText = _display displayCtrl 1004;

// Position the HUD elements (centered, near bottom of screen)
private _hudW = PX(12);
private _hudH = PY(1.2);
private _hudX = safezoneX + safezoneW / 2 - _hudW / 2;
private _hudY = safezoneY + safezoneH - PY(4);

_bg ctrlSetPosition [_hudX - PX(0.2), _hudY - PY(0.2), _hudW + PX(0.4), _hudH + PY(1.8)];
_bg ctrlSetBackgroundColor [0, 0, 0, 0.55];
_bg ctrlSetFade 0;
_bg ctrlCommit 0.2;

_label ctrlSetPosition [_hudX, _hudY - PY(0.1), _hudW, PY(0.8)];
_label ctrlSetText (_sector getVariable [QGVAR(fullName), "Sector"]);
_label ctrlSetFade 0;
_label ctrlCommit 0.2;

_bar ctrlSetPosition [_hudX, _hudY + PY(0.8), 0, _hudH];
_bar ctrlSetBackgroundColor [1, 1, 1, 0.7];
_bar ctrlSetFade 0;
_bar ctrlCommit 0;

_pctText ctrlSetPosition [_hudX, _hudY + PY(0.8), _hudW, _hudH];
_pctText ctrlSetText "0%";
_pctText ctrlSetFade 0;
_pctText ctrlCommit 0.2;

// ======================================================================
// Smoothly interpolate the progress bar via a PFH
// ======================================================================
if (!isNil QGVAR(hudPFH)) then {
    [GVAR(hudPFH)] call PRA3_fw_removePFH;
};

GVAR(hudPFH) = [{
    params ["_sector", "_barCtrl", "_pctCtrl", "_hudX", "_hudW", "_hudY", "_hudH"];

    if (isNull _sector) exitWith {};

    private _progress    = _sector getVariable [QGVAR(captureProgress), 0];
    private _ownerSide   = _sector getVariable [QGVAR(ownerSide), sideUnknown];
    private _attackSide  = _sector getVariable [QGVAR(attackingSide), sideUnknown];

    // Determine bar colour based on who is making progress
    private _barColor = if (_ownerSide isEqualTo sideUnknown) then {
        // Capturing phase: colour by attacker
        switch (_attackSide) do {
            case west:        { [0.1, 0.4, 0.8, 0.85] };
            case east:        { [0.8, 0.1, 0.1, 0.85] };
            case independent: { [0.1, 0.7, 0.2, 0.85] };
            default           { [0.7, 0.7, 0.7, 0.85] };
        };
    } else {
        // Neutralising phase: colour by defender (fading away)
        switch (_ownerSide) do {
            case west:        { [0.1, 0.4, 0.8, 0.85] };
            case east:        { [0.8, 0.1, 0.1, 0.85] };
            case independent: { [0.1, 0.7, 0.2, 0.85] };
            default           { [0.7, 0.7, 0.7, 0.85] };
        };
    };

    _barCtrl ctrlSetBackgroundColor _barColor;

    // Smoothly animate the bar width
    private _targetW = _hudW * _progress;
    _barCtrl ctrlSetPosition [_hudX, _hudY + PY(0.8), _targetW, _hudH];
    _barCtrl ctrlCommit 0.15;

    // Update percentage text
    private _pct = round (_progress * 100);
    _pctCtrl ctrlSetText format ["%1%%", _pct];

}, 0.1, [_sector, _bar, _pctText, _hudX, _hudW, _hudY, _hudH]] call PRA3_fw_addPFH;
