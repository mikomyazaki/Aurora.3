/datum/node
	var/datum/graph/graph

/datum/node/Destroy()
	graph.Disconnect(src)
	return ..()

/datum/node/proc/get_edges()
	return graph.edges[src]

/datum/node/physical
	var/atom/holder

/datum/node/physical/New(var/atom/holder)
	..()
	if(!istype(holder))
		CRASH("Invalid holder: [log_info_line(holder)]");
	src.holder = holder

/datum/node/physical/Destroy()
	holder = null
	. = ..()