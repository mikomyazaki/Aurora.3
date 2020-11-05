// #define ATMOS_DEFAULT_VOLUME_PIPE   70  // L.

#define ATMOS_PIPE_DEFAULT_MAX_PRESSURE     70*ONE_ATMOSPHERE
#define ATMOS_PIPE_DEFAULT_FATIGUE_PRESSURE 55*ONE_ATMOSPHERE
#define ATMOS_PIPE_DEFAULT_ALERT_PRESSURE   55*ONE_ATMOSPHERE

#define MIN_FLOW 0 // Minimum amount of moles that its worth doing leakage for
#define GAS_FLOW_RATE world.fps // Adjustment for volumetric flow rate per tick in e.g. leaking pipes