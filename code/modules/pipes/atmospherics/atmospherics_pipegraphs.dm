/datum/graph/pipe/atmospherics
    var/datum/gas_mixture/gas
    var/max_pressure

/datum/graph/pipe/atmospherics/New()
    . = ..()
    
    gas = new

    var/total_volume = 0
    for(var/n in nodes)
        var/datum/node/physical/pipe/atmospherics/N = n
        total_volume += N.get_pipe().volume

    gas.volume = total_volume

    update_max_pressure()

/datum/graph/pipe/atmospherics/proc/update_max_pressure()
    for(var/n in nodes)
        var/datum/node/physical/pipe/atmospherics/N = n
        max_pressure = max_pressure ? min(max_pressure, N.get_pipe().max_pressure) : N.get_pipe().max_pressure

/datum/node/physical/pipe/atmospherics
    graph_type = /datum/graph/pipe/atmospherics

/datum/node/physical/pipe/atmospherics/get_pipe()
    RETURN_TYPE(/obj/pipe/atmospherics)
    var/obj/pipe/atmospherics/P = holder
    return P