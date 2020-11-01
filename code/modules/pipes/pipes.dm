// Basic pipe object that does not carry anything, only handles connection behavior
/obj/pipe
    layer = PIPE_LAYER

    var/node_type = /datum/node/physical/pipe
    var/datum/node/physical/pipe/node // This node represents this pipe when added to a pipegraph
    var/list/connection_dirs = PIPE_DIR_NONE // Contains a list of directions this pipe may connect via, will set connections and connection_limit in init. One connection per direction. Assumes initial dir is NORTH.
    var/connection_limit // Max number of connections, calculated from connection_dirs

    var/list/valid_connection_types // If defined, this pipe will only be able to connect to types & subtypes in this list
    var/list/valid_connection_types_strict // If defined, this pipe will ONLY connect to types in this list

    var/secure = TRUE // Can we be unwrenched?

//-----------------------------------
// Initialization & Destruction
//-----------------------------------

/obj/pipe/Initialize(mapload)
    . = ..()
    
    if(mapload)
        return INITIALIZE_HINT_LATELOAD
    
    node = new node_type(src)

    set_directions()

    connection_limit = length(connection_dirs)
    connect_all()

    update_icon()

/obj/pipe/Destroy()
    disconnect_all()
    return ..()

//-----------------------------------
// Connection/Disconnection
//-----------------------------------

// Connect to one target pipe
/obj/pipe/proc/connect(var/obj/pipe/P)
    testing("Trying to connect to [P]")
    preConnect(P)
    if(connection_check(P) && connect_to(P))
        onConnect(P)
        return TRUE

/obj/pipe/proc/preConnect(var/obj/pipe/P)
    return

/obj/pipe/proc/onConnect(var/obj/pipe/P)
    testing("Connected to pipe!")
    return

// Connect to first pipe we find in direction
/obj/pipe/proc/connect_in_dir(var/d)
    var/obj/pipe/P = locate() in get_step(src, d)
    return P && connect(P)

// Connect to the first pipes we find at each connection direction, returns TRUE if we made at least one connection
/obj/pipe/proc/connect_all()
    for(var/d in connection_dirs)
        if(d in get_connected_directions())
            continue
        if(connect_in_dir(d))
            . = TRUE

// Disconnect from one target pipe
/obj/pipe/proc/disconnect(var/obj/pipe/P)
    preDisconnect(P)
    . = disconnect_from(P)
    if(.)
        onDisconnect(P)

/obj/pipe/proc/preDisconnect(var/obj/pipe/P)
    return

/obj/pipe/proc/onDisconnect(var/obj/pipe/P)
    return

// Disconnect from all current connections, returns TRUE if we disconnect from at least one connected pipe
/obj/pipe/proc/disconnect_all()
    for(var/obj/pipe/P in get_connected_pipes())
        if(disconnect(P))
            . = TRUE

//-----------------------------------
// Icons
//-----------------------------------


//-----------------------------------
// Processing
//-----------------------------------


//-----------------------------------
// Other
//-----------------------------------
/obj/pipe/Move()
    disconnect_all()
    return ..()

/obj/pipe/forceMove()
    disconnect_all()
    return ..()
