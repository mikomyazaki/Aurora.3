/obj/pipe/atmospherics
    node_type = /datum/node/physical/pipe/atmospherics

    valid_connection_types = list(/obj/pipe/atmospherics)

    var/volume = ATMOS_DEFAULT_VOLUME_PIPE
    var/max_pressure = ATMOS_PIPE_DEFAULT_MAX_PRESSURE

    var/leaking = FALSE
    var/can_leak = TRUE // some pipes may have automatic shutoffs

/obj/pipe/atmospherics/Destroy()
    // Release contained gas into the environment
    return ..()

/obj/pipe/atmospherics/onConnect(var/obj/pipe/atmospherics/P)
    ..()
    // Update graph gases + check pressure

    // Update graph volume
    change_volume(volume)
    // Update graph max_pressure
    get_graph().update_max_pressure()

    // Check if we're leaking
    update_leaking()
    P.update_leaking()

/obj/pipe/atmospherics/preDisconnect(var/obj/pipe/atmospherics/P)
    ..()
    // Update graph volume
    change_volume(-volume)

/obj/pipe/atmospherics/onDisconnect(var/obj/pipe/atmospherics/P)
    ..()

    // Update graph gases + check pressure
    get_graph().update_max_pressure()

    // Check if we're leaking
    update_leaking()
    P.update_leaking()

/obj/pipe/atmospherics/process()
    if(!leaking)
        return PROCESS_KILL
    // Make graph pressure equalize with environment pressure

/obj/pipe/atmospherics/proc/update_leaking()
    leaking = !can_leak && HAS_FREE_CONNECTIONS
    if(leaking)
        START_PROCESSING(SSprocessing, src)
    else
        STOP_PROCESSING(SSprocessing, src)


/obj/pipe/atmospherics/update_icon()