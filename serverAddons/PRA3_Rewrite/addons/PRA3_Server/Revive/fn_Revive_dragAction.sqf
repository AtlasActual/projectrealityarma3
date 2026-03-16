#include "script_component.hpp"
/*
    FUNC(dragAction)

    Description:
        Allows a player to drag an unconscious friendly unit. The target
        is attached to the dragger and the dragger is forced to walk
        speed. Dragging ends automatically if the dragger enters a
        vehicle, dies, or manually releases.

    Params:
        0: _caller - OBJECT - the unit doing the dragging
        1: _target - OBJECT - the unconscious unit to drag

    Returns: nothing
*/

params ["_caller", "_target"];

// ======================================================================
// 1. Validate conditions
// ======================================================================
if (!alive _target) exitWith {};
if !(_target getVariable [QGVAR(unconscious), false]) exitWith {};
if (side group _target isNotEqualTo side group _caller) exitWith {};
if (GVAR(isDragging)) exitWith { hint "Already dragging someone." };
if (_caller distance _target > 4) exitWith {};

// ======================================================================
// 2. Attach target to dragger
// ======================================================================
_target attachTo [_caller, [0, -1.2, 0]];
_target setDir 180;

// Force walk speed on the dragger
_caller forceWalk true;

// Play dragging animation
_caller playMove "AcinPknlMstpSnonWnonDnon";

// ======================================================================
// 3. Track dragging state
// ======================================================================
GVAR(isDragging) = true;
GVAR(dragTarget) = _target;

_caller setVariable [QGVAR(isDragging), true, true];

// ======================================================================
// 4. Add release action
// ======================================================================
private _releaseActionId = _caller addAction [
    MLOC(DropAction),
    {
        params ["_unit", "_caller", "_actionId"];

        private _draggedUnit = GVAR(dragTarget);

        if (!isNull _draggedUnit) then {
            detach _draggedUnit;

            // Place on ground properly
            private _dropPos = _unit modelToWorld [0, -2, 0];
            _dropPos set [2, 0];
            _draggedUnit setPos _dropPos;
        };

        _unit forceWalk false;
        _unit removeAction _actionId;

        GVAR(isDragging) = false;
        GVAR(dragTarget) = objNull;
        _unit setVariable [QGVAR(isDragging), false, true];
    },
    nil, 6, false, true, "",
    "true"
];

// ======================================================================
// 5. Monitor loop: auto-drop if dragger enters vehicle or dies
// ======================================================================
[{
    params ["_args", "_pfhId"];
    _args params ["_caller", "_target", "_releaseActionId"];

    private _shouldDrop = false;

    // Dragger died
    if (!alive _caller) then { _shouldDrop = true };

    // Dragger entered a vehicle
    if (vehicle _caller isNotEqualTo _caller) then { _shouldDrop = true };

    // Target died
    if (!alive _target) then { _shouldDrop = true };

    // Target is no longer unconscious (revived while being dragged)
    if !(_target getVariable [QGVAR(unconscious), false]) then { _shouldDrop = true };

    // Dragging state was cleared externally
    if (!GVAR(isDragging)) exitWith {
        _pfhId call PRA3_fw_removePFH;
    };

    if (_shouldDrop) exitWith {
        _pfhId call PRA3_fw_removePFH;

        detach _target;

        if (alive _caller) then {
            _caller forceWalk false;
            _caller removeAction _releaseActionId;
        };

        // Place target on ground
        private _tgtPos = getPosATL _target;
        _tgtPos set [2, 0];
        _target setPosATL _tgtPos;

        GVAR(isDragging) = false;
        GVAR(dragTarget) = objNull;

        if (alive _caller) then {
            _caller setVariable [QGVAR(isDragging), false, true];
        };
    };

}, 0.5, [_caller, _target, _releaseActionId]] call PRA3_fw_addPFH;
