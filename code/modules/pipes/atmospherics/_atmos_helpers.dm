//-----------------------------------
// Graph Helpers
//-----------------------------------

/obj/pipe/atmospherics/get_graph()
    RETURN_TYPE(/datum/graph/pipe/atmospherics)
    return node.graph

/obj/pipe/atmospherics/get_node()
    RETURN_TYPE(/datum/node/physical/pipe/atmospherics)
    return node

//-----------------------------------
// Gas Mixture Helpers
//-----------------------------------

/obj/pipe/atmospherics/proc/get_gas()
    RETURN_TYPE(/datum/gas_mixture)
    var/datum/graph/pipe/atmospherics/G = get_graph()
    return G.gas

/obj/pipe/atmospherics/proc/get_gas_list()
    var/datum/gas_mixture/G = get_gas()
    return G.gas

//-----------------------------------
// Volume Helpers
//-----------------------------------

/obj/pipe/atmospherics/proc/get_volume()
    var/datum/gas_mixture/G = get_gas()
    return G.volume

/obj/pipe/atmospherics/proc/change_volume(var/delta)
    var/datum/gas_mixture/G = get_gas()
    G.volume += delta

/obj/pipe/atmospherics/proc/set_volume(var/volume)
    var/datum/gas_mixture/G = get_gas()
    G.volume = volume

//-----------------------------------
// Temperature Helpers
//-----------------------------------

/obj/pipe/atmospherics/proc/get_temperature()
    var/datum/gas_mixture/G = get_gas()
    return G.temperature

/obj/pipe/atmospherics/proc/change_temperature(var/delta)
    var/datum/gas_mixture/G = get_gas()
    G.temperature += delta

/obj/pipe/atmospherics/proc/set_temperature(var/temperature)
    var/datum/gas_mixture/G = get_gas()
    G.temperature = temperature

//-----------------------------------
// Moles Helpers
//-----------------------------------

/obj/pipe/atmospherics/proc/get_total_moles()
    var/datum/gas_mixture/G = get_gas()
    return G.total_moles

/obj/pipe/atmospherics/proc/change_total_moles(var/delta)
    var/datum/gas_mixture/G = get_gas()
    G.total_moles += delta

/obj/pipe/atmospherics/proc/set_total_moles(var/total_moles)
    var/datum/gas_mixture/G = get_gas()
    G.total_moles = total_moles

//-----------------------------------
// Physics Helpers
//-----------------------------------

// Simplified Poiseuille's Equation - Assumes pipe is cylindrical, and that the pressure drop is over exactly one pipe segment
/obj/pipe/atmospherics/proc/volumetric_flow(var/pressure_delta, var/length = 1, var/viscosity = 1)
    return (pressure_delta * volume**2) / (8 * length * viscosity * M_PI) * GAS_FLOW_RATE