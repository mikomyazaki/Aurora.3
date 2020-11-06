/obj/pipe/atmospherics
    node_type = /datum/node/physical/pipe/atmospherics

    valid_connection_types = list(/obj/pipe/atmospherics)

    var/volume = ATMOS_DEFAULT_VOLUME_PIPE
    var/max_pressure = ATMOS_PIPE_DEFAULT_MAX_PRESSURE

    var/leaking = FALSE
    var/can_leak = TRUE // some pipes may have automatic shutoffs

/obj/pipe/atmospherics/Destroy()
    // Release contained gas into the environment
    loc.assume_air(split_pipe_gas_share())
    return ..()

/obj/pipe/atmospherics/onConnect(var/obj/pipe/atmospherics/P)
    ..()
    // Update graph gases
    change_volume(volume)
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

    // Update graph gases
    get_graph().update_max_pressure()

    // Check if we're leaking
    update_leaking()
    P.update_leaking()

/obj/pipe/atmospherics/process()
    if(!leaking)
        return PROCESS_KILL
    // Make graph pressure equalize with environment pressure
    var/datum/gas_mixture/environment = loc.return_air()
    var/datum/gas_mixture/gas = get_gas()

    var/pressure_delta = environment.return_pressure() - gas.return_pressure()
    if(pressure_delta < 0)
        var/flow = volumetric_flow(pressure_delta)
        if(flow >= MIN_FLOW)
            // transfer flow amount of gas from pipe to environment
            environment.merge(gas.remove(flow))
    //else
        // Gas flows into pipe

/obj/pipe/atmospherics/proc/update_leaking()
    leaking = can_leak && HAS_FREE_CONNECTIONS
    if(leaking)
        START_PROCESSING(SSprocessing, src)
    else
        STOP_PROCESSING(SSprocessing, src)
    return leaking

/obj/pipe/atmospherics/update_icon()

/obj/pipe/atmospherics/proc/fill_with_gas_test()
    var/datum/gas_mixture/gas = get_gas()
    var/turf/T = get_turf(src)
    var/datum/gas_mixture/environment = T.return_air()
    
    gas.gas = environment.gas.Copy()
    gas.temperature = environment.temperature
    gas.total_moles = environment.total_moles   