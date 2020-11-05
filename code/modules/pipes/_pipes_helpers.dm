//-----------------------------------
// Connection Helpers
//-----------------------------------

/obj/pipe/proc/get_connected_pipes()
    . = list()
    for(var/N in node.get_edges())
        var/datum/node/physical/pipe/connected_node = N
        . += connected_node.get_pipe()

/obj/pipe/proc/get_connected_directions()
    . = list()
    for(var/obj/pipe/P in get_connected_pipes())
        . += get_dir(P, src)

/obj/pipe/proc/are_connected_to(var/obj/pipe/target)
    for(var/pipe in get_connected_pipes())
        var/obj/pipe/P = pipe
        if(P == target)
            return TRUE

// Queues a connection to the target
/obj/pipe/proc/connect_to(var/obj/pipe/target)
    return node.graph.Connect(target.node, node)

// Queues a disconnection from the target
/obj/pipe/proc/disconnect_from(var/obj/pipe/target)
    return node.graph.Disconnect(target.node, node)

// Checks for pipe connection suitability
/obj/pipe/proc/connection_check(var/obj/pipe/target)
    SHOULD_CALL_PARENT(TRUE)
    if(!Adjacent(target))
        testing("Connection check failed adjacency check.")
        return FALSE
    else if(!(may_connect(target) && target.may_connect(src)))
        testing("Connection check failed in may_connect.")    
        return FALSE
    return TRUE

/obj/pipe/proc/may_connect(var/obj/pipe/target)
    SHOULD_CALL_PARENT(TRUE)
    // src connection checks
    if(NO_FREE_CONNECTIONS) // Free connection slots?
        testing("Not enough connection slots.")
        return FALSE
    else if(!istype(target)) // Are we sure that's a pipe?
        testing("Target is not a pipe.")
        return FALSE
    else if(are_connected_to(target)) // Are we already connected?
        testing("We are already connected to the target.")
        return FALSE
    else if(!valid_connection_type(target)) // Can we connect to that?
        testing("Target is not in our valid connection types.")
        return FALSE
    else if(!isturf(loc)) // Are we inside something?
        testing("Target is not on a turf.")
        return FALSE
    else if(!(get_dir(target, src) in connection_dirs)) // Is it in the right direction?
        testing("Target not in allowed connection directions.")
        return FALSE
    else if(length(get_connected_directions() & get_dir(target, src))) // It's an allowed direction, but is that direction free?
        testing("We are already connected to a pipe in that direction.")
    return TRUE

// Are we allowed to connect to this type of pipe?
/obj/pipe/proc/valid_connection_type(var/obj/P)
    . = FALSE
    if(valid_connection_types_strict)
        if(!(P in valid_connection_types_strict))
            . = FALSE
    else if(valid_connection_types)
        for(var/type in valid_connection_types)
            . = istype(P, type)
    else
        return TRUE

//-----------------------------------
// Direction Helpers
//-----------------------------------

/obj/pipe/proc/set_directions(var/new_dir)
    dir = new_dir
    var/angle = dir2angle(initial(dir)) - dir2angle(dir) // Angle to rotate ccw
    for(var/d in 1 to connection_dirs.len)
        if(connection_dirs[d] in cardinal)
            connection_dirs[d] = turn(connection_dirs[d], angle)

    if(!check_dirs())
        CRASH("Pipe given invalid pipe direction after rotation by [angle] degrees.")

    return TRUE

/obj/pipe/proc/check_dirs()
    . = TRUE
    for(var/d in 1 to connection_dirs.len)
        if(!(connection_dirs[d] in ALLOWED_PIPE_DIRECTIONS))
            . = FALSE