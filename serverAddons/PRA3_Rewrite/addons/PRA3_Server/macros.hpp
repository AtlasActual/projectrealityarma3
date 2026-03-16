#include "modInfo.hpp"

// --- String macros ---
#define QUOTE(x) #x
#define DOUBLES(a,b) a##_##b
#define TRIPLES(a,b,c) a##_##b##_##c
#define DOUBLE(a,b) DOUBLES(a,b)
#define TRIPLE(a,b,c) TRIPLES(a,b,c)

// --- Module detection ---
// MODULE is set per-file via CfgFunctions or manually
// Current module name — set in each subfolder's script_component.hpp
// e.g. #define COMPONENT Common
// e.g. #define COMPONENT Sector

// --- Variable macros ---
// GVAR(varName) => PRA3_Common_varName (module-scoped global)
#define GVAR(var) TRIPLES(PREFIX,COMPONENT,var)
#define QGVAR(var) QUOTE(GVAR(var))

// EGVAR(module,var) => PRA3_module_var (cross-module global)
#define EGVAR(module,var) TRIPLES(PREFIX,module,var)
#define QEGVAR(module,var) QUOTE(EGVAR(module,var))

// --- Function macros ---
// FUNC(name) => PRA3_fnc_COMPONENT_name
#define FUNC(name) TRIPLES(PREFIX,fnc,DOUBLES(COMPONENT,name))
#define QFUNC(name) QUOTE(FUNC(name))

// EFUNC(module,name) => PRA3_fnc_module_name
#define EFUNC(module,name) TRIPLES(PREFIX,fnc,DOUBLES(module,name))
#define QEFUNC(module,name) QUOTE(EFUNC(module,name))

// DFUNC — define a function variable (for inline function definitions)
#define DFUNC(name) FUNC(name)

// --- Framework function macros ---
// Framework functions live in PRA3_fnc_fw_*
#define FWFUNC(name) TRIPLES(PREFIX,fnc,DOUBLES(fw,name))
#define QFWFUNC(name) QUOTE(FWFUNC(name))

// --- UI macros ---
#define UIVAR(name) QUOTE(DOUBLES(PREFIX,name))

// --- Localization ---
// MLOC(key) => localized string from our localization hashmap
#define MLOC(key) (GVAR(loc) getOrDefault [QUOTE(key), QUOTE(key)])
#define EMLOC(module,key) (EGVAR(module,loc) getOrDefault [QUOTE(key), QUOTE(key)])

// --- Pixel math for UI (same as original) ---
#define PX(n) ((n) * (((safezoneW / safezoneH) min 1.2) / 40))
#define PY(n) ((n) * ((((safezoneW / safezoneH) min 1.2) / 1.2) / 25))
