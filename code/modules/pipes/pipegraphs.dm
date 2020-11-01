/datum/graph/pipe

/datum/graph/pipe/New()
	. = ..()
	pipegraphs += src

/datum/graph/pipe/Destroy()
	pipegraphs -= src
	return ..()


/datum/node/physical/pipe
    var/graph_type = /datum/graph/pipe

/datum/node/physical/pipe/New()
    . = ..()
    graph = new graph_type(list(src))

/datum/node/physical/pipe/Destroy()
    if(graph.nodes.len == 1)
        qdel(graph)
    return ..()

/datum/node/physical/pipe/proc/get_pipe()
    RETURN_TYPE(/obj/pipe)
    var/obj/pipe/P = holder
    return P