#include "script_component.hpp"
/*
    PRA3_fnc_fw_bootstrap

    Description:
        Bootstrap function called from Common preInit.
        Initializes all framework subsystems in the correct order.
        Sets PRA3_fw_ready to true when all systems are operational.
*/

GVAR(ready) = false;

diag_log "[PRA3] Framework bootstrap starting...";
diag_log format ["[PRA3] Framework v%1.%2.%3.%4", MAJOR, MINOR, PATCHLVL, BUILD];

// 1. Event bus -- must be first, other systems may register events
[] call FWFUNC(eventBus);
diag_log "[PRA3] Bootstrap: event bus ready";

// 2. Per-frame handler system
[] call FWFUNC(perFrame);
diag_log "[PRA3] Bootstrap: per-frame handlers ready";

// 3. State machine system (depends on PFH)
[] call FWFUNC(stateMachine);
diag_log "[PRA3] Bootstrap: state machine ready";

// 4. Mutex system (depends on event bus for remote calls)
[] call FWFUNC(mutex);
diag_log "[PRA3] Bootstrap: mutex ready";

// 5. Utility functions
[] call FWFUNC(utilities);
diag_log "[PRA3] Bootstrap: utilities ready";

// 6. Localization (may use utilities for config loading)
[] call FWFUNC(localization);
diag_log "[PRA3] Bootstrap: localization ready";

// Mark framework as fully initialized
GVAR(ready) = true;

diag_log "[PRA3] Framework bootstrap complete -- all systems operational";
