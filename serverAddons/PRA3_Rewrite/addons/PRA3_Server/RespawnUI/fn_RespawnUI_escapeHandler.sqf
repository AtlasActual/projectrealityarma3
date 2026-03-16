#include "script_component.hpp"
/*
    FUNC(escapeHandler)

    Description:
        KeyDown event handler that intercepts the Escape key while the
        respawn screen is open. Opens a minimal interrupt dialog with
        only the "Abort" button enabled, preventing access to the
        normal game options menu during respawn.

    Parameters:
        0: _display  - DISPLAY - the respawn screen display
        1: _dikCode  - NUMBER  - the DIK keycode pressed
        2: _shift    - BOOL    - shift state
        3: _ctrl     - BOOL    - ctrl state
        4: _alt      - BOOL    - alt state

    Returns:
        BOOL - true if the key was handled, false to pass through
*/

params ["_display", "_dikCode"];

// Only intercept the Escape key (DIK code 1)
if (_dikCode != 1) exitWith { false };

// Hide all control groups (100-900) while the interrupt dialog is shown
for "_g" from 1 to 9 do {
    private _grpCtrl = _display displayCtrl (_g * 100);
    _grpCtrl ctrlShow false;
};

// Open the engine's built-in interrupt dialog
private _dialogClass = if (isMultiplayer) then {
    "RscDisplayMPInterrupt"
} else {
    "RscDisplayInterrupt"
};
createDialog _dialogClass;

private _interruptDisp = findDisplay 49;

// Disable every button in the interrupt dialog (range 100..2000)
for "_idc" from 100 to 2000 do {
    private _ctrl = _interruptDisp displayCtrl _idc;
    _ctrl ctrlEnable false;
    _ctrl ctrlSetTooltip "";
};

// Re-enable only the Abort button (IDC 104) with custom behavior
private _abortBtn = _interruptDisp displayCtrl 104;
_abortBtn ctrlEnable true;
_abortBtn ctrlSetText "ABORT";

// When Abort is clicked: close respawn screen, close dialog, fail mission
_abortBtn ctrlSetEventHandler [
    "buttonClick",
    "(uiNamespace getVariable ['PRA3_RespawnUI_respawnDisplay', displayNull]) closeDisplay 2; closeDialog 0; failMission 'LOSER';"
];

// Restore control group visibility once the interrupt dialog closes
[{
    params ["_display"];

    for "_g" from 1 to 9 do {
        private _grpCtrl = _display displayCtrl (_g * 100);
        _grpCtrl ctrlShow true;
    };
}, { !dialog }, [_display]] call PRA3_fw_waitUntilExec;

// Mark as handled so the engine does not process Escape further
true
