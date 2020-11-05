// Contains a list of all graphs currently initialized that contain pipes, for debugging purposes
var/global/list/datum/graph/pipegraphs = list()

#define ALLOWED_PIPE_DIRECTIONS list(NORTH, SOUTH, EAST, WEST, UP, DOWN)

// Helper Macros
#define NUM_CONNECTIONS length(node.get_edges())
#define HAS_FREE_CONNECTIONS (NUM_CONNECTIONS < connection_limit)
#define NO_FREE_CONNECTIONS (NUM_CONNECTIONS == connection_limit)

// Pipe directions
#define PIPE_END list(NORTH)
#define PIPE_STRAIGHT list(NORTH, SOUTH)
#define PIPE_TEE list(NORTH, EAST, SOUTH)
#define PIPE_CROSS list(NORTH, EAST, SOUTH, WEST)
#define PIPE_UP list(UP)
#define PIPE_DOWN list(DOWN)