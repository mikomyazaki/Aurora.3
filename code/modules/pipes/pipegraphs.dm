/datum/graph/pipe

/datum/graph/pipe/New()
	. = ..()
	pipegraphs += src

/datum/graph/pipe/Destroy()
	pipegraphs -= src
	return ..()


/datum/node/physical/pipe

/datum/node/physical/pipe/New()
    . = ..()
    graph = new/datum/graph/pipe(list(src))

/datum/node/physical/pipe/Destroy()
    if(graph.nodes.len == 1)
        qdel(graph)
    return ..()

/datum/node/physical/pipe/proc/get_pipe()
    return holder