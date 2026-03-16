#include "script_component.hpp"
/*
    FUNC(apply)

    Description:
        Server-side handler that subscribes to the "entityCreated" event.
        For every newly created entity it resolves the entity's type against
        missionConfigFile >> "PRA3" >> "CfgEntities", traverses the full
        config inheritance tree from the most derived class upward, and
        applies every discovered property as a public variable on the entity.
        Child-class properties take precedence over identically named
        parent-class properties.

    Usage:
        Automatically invoked by the module loader on the server.
*/

if (!isServer) exitWith {};

["entityCreated", {
    params ["_entity"];

    if (isNull _entity) exitWith {};

    private _className = typeOf _entity;
    private _cfgBase = missionConfigFile >> "PRA3" >> "CfgEntities";
    private _classEntry = _cfgBase >> _className;

    // Bail out when the entity type has no config definition
    if (!isClass _classEntry) exitWith {};

    // Walk the inheritance chain and gather every property.
    // Properties discovered first (child class) are kept; duplicates
    // encountered higher up (parent classes) are ignored.
    private _variables = createHashMap;
    private _cursor = _classEntry;

    while {isClass _cursor && {configName _cursor != ""}} do {
        private _numEntries = count _cursor;

        for "_idx" from 0 to (_numEntries - 1) do {
            private _entry = _cursor select _idx;

            // Sub-classes are not properties -- skip them
            if (!isClass _entry) then {
                private _name = configName _entry;

                // Preserve child-class value when a name collision occurs
                if !(_name in _variables) then {
                    private _value = call {
                        if (isNumber _entry) exitWith { getNumber _entry };
                        if (isText   _entry) exitWith { getText   _entry };
                        if (isArray  _entry) exitWith { getArray  _entry };
                        nil
                    };

                    if (!isNil "_value") then {
                        _variables set [_name, _value];
                    };
                };
            };
        };

        _cursor = inheritsFrom _cursor;
    };

    // Publish every collected property onto the entity so that all
    // machines can read them with getVariable
    {
        _entity setVariable [_x, _y, true];
    } forEach _variables;

    diag_log format [
        "[PRA3 EntityVariables] Set %1 vars on %2 (type: %3)",
        count _variables,
        _entity,
        _className
    ];

}] call PRA3_fw_addHandler;

diag_log "[PRA3 EntityVariables] Entity variable applicator ready.";
