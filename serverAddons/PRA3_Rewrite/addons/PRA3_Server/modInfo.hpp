#define PREFIX PRA3
#define PATH pr
#define MOD PRA3_Server

// Version Information
#define MAJOR 1
#define MINOR 0
#define PATCHLVL 0
#define BUILD 1

#ifdef VERSION
    #undef VERSION
#endif
#ifdef VERSION_AR
    #undef VERSION_AR
#endif
#define VERSION_AR MAJOR,MINOR,PATCHLVL,BUILD
#define VERSION MAJOR.MINOR.PATCHLVL.BUILD

// #define DEBUGFULL
#define isDev
