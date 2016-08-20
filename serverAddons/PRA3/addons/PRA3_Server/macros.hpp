// Base Includes
#include "modInfo.hpp"

// Check Debug settings
#ifdef PRA3_DEBUGFULL
    #define isDev
#endif

#ifdef PRA3_DEBUGFULL
    #define ENABLEPERFORMANCECOUNTER
#endif

#ifdef PRA3_DEBUGFULL
    #define ENABLEFUNCTIONTRACE
#endif



// Predefines for easy Macro work
#define DOUBLE(var1,var2) var1##_##var2
#define TRIPLE(var1,var2,var3) DOUBLE(var1,DOUBLE(var2,var3))

#define QUOTE(var) #var

#define FUNCPATH(var) \##PATH\##PREFIX\addons\##MOD\##MODULE\fn_##var.sqf
#define FFNCPATH(subModule,var) \##PATH\##PREFIX\addons\##MOD\##MODULE\##subModule\fn_##var.sqf

// Global Varible Macros
#define EGVAR(var1,var2) TRIPLE(PREFIX,var1,var2)
#define QEGVAR(var1,var2) QUOTE(EGVAR(var1,var2))

#define GVAR(var) EGVAR(MODULE,var)
#define QGVAR(var) QUOTE(GVAR(var))

#define CGVAR(var1) EGVAR(Core,var1)
#define QCGVAR(var1) QEGVAR(Core,var1)

#define UIVAR(var1) QEGVAR(UI,var1)

// Logging/Dumping macros
#ifdef isDev
    #define DUMP(var) \
        diag_log format ["(%1) [PRA3 LOG - %2]: %3", diag_frameNo, #MODULE, var];\
        systemChat format ["(%1) [PRA3 DUMP - %2]: %3", diag_frameNo, #MODULE, var];\
        if (hasInterface) then {\
            CGVAR(sendlogfile) = [format ["(%1) [PRA3 DUMP - %2]: %3", diag_frameNo, #MODULE, var], format ["%1_%2", profileName, CGVAR(playerUID)]];\
            publicVariableServer QCGVAR(sendlogfile);\
        };
#else
    #define DUMP(var) /* disabled */
#endif

#ifdef isDev
    #define LOG(var) DUMP(var)
#else
    #define LOG(var) diag_log format ["(%1) [PRA3 LOG - %2]: %3", diag_frameNo, #MODULE, var];
#endif


// Function macros
#define EDFUNC(var1,var2) TRIPLE(PREFIX,var1,DOUBLE(fnc,var2))

#define DFUNC(var) EDFUNC(MODULE,var)

#define QEFUNC(var1,var2) QUOTE(EDFUNC(var1,var2))

#define QFUNC(var) QUOTE(DFUNC(var))

#ifdef isDev
    #define EFUNC(var1,var2) (missionNamespace getVariable [QEFUNC(var1,var2), {["Error function %1 dont exist or isNil", QEFUNC(var1,var2)] call BIS_fnc_errorMsg; DUMP(QEFUNC(var1,var2) + " Dont Exist")}])
#endif

#ifdef ENABLEFUNCTIONTRACE
    #undef EFUNC
    #define EFUNC(var1,var2) {\
        DUMP("Function " + QEFUNC(var1,var2) + " called with " + str (_this));\
        private _tempRet = _this call EDFUNC(var1,var2);\
        if (!isNil "_tempRet") then {\
            _tempRet\
        }\
    }
#endif

#ifndef EFUNC
    #define EFUNC(var1,var2) EDFUNC(var1,var2)
#endif

#define FUNC(var) EFUNC(MODULE,var)

#define CFUNC(var) EFUNC(Core,var)
#define QCFUNC(var) QUOTE(EDFUNC(Core,var))

#define PREP(fncName) [QUOTE(FUNCPATH(fncName)), QFUNC(fncName)] call CFUNC(compile);
#define EPREP(folder,fncName) [QUOTE(FFNCPATH(folder,fncName)), QFUNC(fncName)] call CFUNC(compile);

#include "supportMacros.hpp"
