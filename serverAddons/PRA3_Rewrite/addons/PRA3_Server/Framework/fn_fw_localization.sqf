#include "script_component.hpp"
/*
    PRA3_fnc_fw_localization

    Description:
        Simple localization system. Stores translated strings per module
        in HashMaps (PRA3_<module>_loc). Reads the player's preferred
        language from profileNamespace, falling back to "English".

    Called during framework bootstrap.
*/

// ------------------------------------------------------------------
// PRA3_fw_initLoc
//   Reads language preference from profileNamespace.
//   Sets PRA3_fw_language to the selected language string.
// ------------------------------------------------------------------
GVAR(language) = "English";

// Shared empty map used as a safe default to avoid allocating a new
// HashMap on every loc lookup that misses the module variable.
if (isNil QGVAR(emptyMap)) then { GVAR(emptyMap) = createHashMap };

GVAR(initLoc) = {
    private _lang = profileNamespace getVariable ["PRA3_language", "English"];

    if (_lang isEqualTo "") then {
        _lang = "English";
    };

    GVAR(language) = _lang;

    diag_log format ["[PRA3] Localization language set to: %1", _lang];
};

// ------------------------------------------------------------------
// PRA3_fw_loc
//   Params: [module, key]
//   Returns: the localized string for the current language.
//   Lookup order:
//     1. Current language entry in PRA3_<module>_loc
//     2. English fallback in PRA3_<module>_loc
//     3. The raw key string itself
//
//   Each module's loc HashMap structure:
//     key -> HashMap of (languageName -> translatedString)
//   Example:
//     PRA3_Squad_loc = createHashMap;
//     PRA3_Squad_loc set ["joinSquad", createHashMapFromArray [
//         ["English", "Join Squad"],
//         ["German", "Trupp beitreten"]
//     ]];
// ------------------------------------------------------------------
GVAR(loc) = {
    params ["_module", "_key"];

    private _locVarName = format ["PRA3_%1_loc", _module];
    private _locMap = missionNamespace getVariable [_locVarName, GVAR(emptyMap)];

    private _translations = _locMap getOrDefault [_key, GVAR(emptyMap)];

    if (count _translations == 0) exitWith { _key };

    private _lang = GVAR(language);
    private _text = _translations getOrDefault [_lang, ""];

    if (_text isEqualTo "") then {
        _text = _translations getOrDefault ["English", ""];
    };

    if (_text isEqualTo "") then {
        _text = _key;
    };

    _text
};

// Initialize language on load
[] call GVAR(initLoc);

diag_log "[PRA3] Localization system initialized";
