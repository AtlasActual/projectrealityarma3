#include "script_component.hpp"
/*
    FUNC(show)

    Description:
        Enqueues a notification for on-screen display. If the text
        contains "%LOC_<module>_<key>" tokens they are resolved through
        the framework localization system before display. The queue is
        kept sorted by descending priority so that the most important
        message is always shown first.

    Params:
        0: _text          - STRING  - notification message body
        1: _color         - ARRAY   - (default [0.15, 0.15, 0.15, 0.85])
                            RGBA background colour
        2: _duration      - NUMBER  - (default 6) seconds to keep visible
        3: _priority      - NUMBER  - (default 0) higher = shown first
        4: _conditionCode - CODE    - (default {true}) evaluated before
                            display; notification is skipped when false

    Returns: nothing
*/

params [
    "_text",
    ["_color",         [0.15, 0.15, 0.15, 0.85]],
    ["_duration",      6],
    ["_priority",      0],
    ["_conditionCode", {true}]
];

// ---- Inline localisation pass ----
// Tokens look like  %LOC_ModuleName_someKey%
// They are replaced with the value returned by PRA3_fw_loc.
private _processed = _text;
private _searchPos = 0;

while {true} do {
    private _startIdx = _processed find "%LOC_";
    if (_startIdx < 0) exitWith {};

    // Locate closing percent sign after the opening token
    private _tail     = _processed select [_startIdx + 1];
    private _endRel   = _tail find "%";
    if (_endRel < 0) exitWith {};

    private _endIdx   = _startIdx + 1 + _endRel;
    private _token    = _processed select [_startIdx + 5, _endIdx - _startIdx - 5];

    // Token format: ModuleName_keyName
    private _sepIdx   = _token find "_";
    private _locText  = _token;

    if (_sepIdx > 0) then {
        private _locModule = _token select [0, _sepIdx];
        private _locKey    = _token select [_sepIdx + 1];
        _locText = [_locModule, _locKey] call PRA3_fw_loc;
    };

    // Rebuild the string with the translated fragment
    _processed = (_processed select [0, _startIdx]) + _locText + (_processed select [_endIdx + 1]);
};

// ---- Build the queue entry and insert ----
private _entry = [_processed, _color, _duration, _priority, _conditionCode];

GVAR(queue) pushBack _entry;

// Sort descending on priority (index 3)
GVAR(queue) sort false;
GVAR(queue) = GVAR(queue) apply {_x};  // force copy so sort key sticks
GVAR(queue) = [GVAR(queue), [], {_x select 3}] call BIS_fnc_sortBy;

// Kick off display processing when idle
if (!GVAR(processing)) then {
    [] call FUNC(processQueue);
};
