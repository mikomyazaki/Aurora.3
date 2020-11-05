/obj/pipe/simple
    connection_dirs = list(NORTH, SOUTH)

    icon = 'icons/atmos/pipes.dmi'
    icon_state = "intact"

/obj/pipe/simple/manifold
    connection_dirs = list(WEST, NORTH, EAST)

    icon = 'icons/atmos/manifold.dmi'
    icon_state = "map"

/obj/pipe/simple/manifold/four
    connection_dirs = list(NORTH, SOUTH, EAST, WEST)

    icon_state = "map_4way"