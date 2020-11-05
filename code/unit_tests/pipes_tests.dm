#define SUCCESS 1
#define FAILURE 0

/datum/unit_test/pipes
	name = "PIPES template"

/**
 * Check if all defined and mapped pipes have appropriate initial variables
 */
/datum/unit_test/pipes/pipe_directions
	name = "PIPES: Defined pipes shall have at least one connection direction and no invalid connection directions"

/datum/unit_test/pipes/defined_pipes/start_test()
	var/status = SUCCESS
	var/list/invalid_pipe_defs = list()
	var/list/invalid_mapped_pipes = list()

	// Defined Pipes
	for(var/path in subtypesof(/obj/pipe))
		var/obj/pipe/P = new path()

		// Do we have connection_dirs set?
		if(!length(P.connection_dirs))
			invalid_pipe_defs |= path
			status = FAILURE
		
		// Do we have any invalid connection directions?
		for(var/direction in P.connection_dirs)
			if(!(direction in ALLOWED_PIPE_DIRECTIONS))
				invalid_pipe_defs |= path
				status = FAILURE

		// Do we have any connection_dirs with duplicate directions?
		if(length(P.connection_dirs) != length(uniquelist(P.connection_dirs)))
			invalid_pipe_defs |= path
			status = FAILURE
		
		qdel(P)

	// Mapped Pipes
	for(var/obj/pipe/P in world)
		// Do we have connection_dirs set?
		if(!length(P.connection_dirs))
			invalid_mapped_pipes |= P
			status = FAILURE

		// Do we have any invalid connection directions?
		for(var/direction in P.connection_dirs)
			if(!(direction in ALLOWED_PIPE_DIRECTIONS))
				invalid_mapped_pipes |= P
				. = FAILURE
	
		// Do we have any connection_dirs with duplicate directions?
		if(length(P.connection_dirs) != length(uniquelist(P.connection_dirs)))
			invalid_mapped_pipes |= P
			status = FAILURE
	
	if(!status)
		if(length(invalid_pipe_defs))
			log_unit_test("[ascii_red]--------------- [length(invalid_pipe_defs)] invalid pipes were found.")

			for(var/pipe in invalid_pipe_defs)
				log_unit_test("[ascii_red]--------------- [pipe]")

		if(length(invalid_mapped_pipes))
			log_unit_test("[ascii_red]--------------- [length(invalid_mapped_pipes)] invalid mapped pipes were found.")

			for(var/obj/pipe/P in invalid_mapped_pipes)
				var/turf/T = get_turf(P)
				log_unit_test("[ascii_red]--------------- Invalid mapped pipe of type [P.type] was found at [T.x] [T.y] [T.z].")
	else
		pass("All defined and mapped pipes have valid connection_dirs set.")

	return 1

/**
 * Check if all mapped pipes may be connected unambiguously
 */
/datum/unit_test/pipes/pipe_connections
	name = "PIPES: Mapped pipes shall have unambiguous connections."

/datum/unit_test/pipes/pipe_connections/start_test()
	// Check all pipes are mapped next to one or less valid connection choices

	return 1

#undef SUCCESS
#undef FAILURE