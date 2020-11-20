// Used to process turrets and handle target finding

var/datum/controller/subsystem/processing/turrets/SSturrets
/datum/controller/subsystem/processing/turrets
	name = "Turrets"
	priority = SS_PRIORITY_TURRETS
	stat_tag = "Turrets"

	var/list/list/close_turrets

/datum/controller/subsystem/processing/turrets/New()
	testing("NEWED TURRET SUBSYSTEM")
	NEW_SS_GLOBAL(SSturrets)

/datum/controller/subsystem/processing/turrets/fire(resumed = 0)
    testing("Firing turret SS!")
    if(isemptylist(processing))
        for(var/turret in close_turrets)
            LAZYCLEARLIST(close_turrets[turret])
        LAZYCLEARLIST(close_turrets)
        testing("No turrets being processed.")
        return

    LAZYINITLIST(close_turrets)
    if(!same_entries(processing, list_keys(close_turrets)))
        testing("Finding close turrets for [processing.len] turrets")
        find_close_turrets()

    testing("Finding targets")
    find_targets()

    ..() // runs process on each turret

/datum/controller/subsystem/processing/turrets/proc/find_close_turrets()
    LAZYCLEARLIST(close_turrets)
    for(var/T in processing)
        var/obj/machinery/porta_turret/turret = T
        LAZYADD(close_turrets[turret], turret)
        for(var/other_T in (processing - close_turrets[turret]))
            var/obj/machinery/porta_turret/other_turret = T
            var/turf/turret_turf = get_turf(turret)
            var/turf/other_turret_turf = get_turf(other_turret)

            if(turret_turf.z == other_turret_turf.z && (between(0, get_dist(turret_turf, other_turret_turf), min(turret.turret_range, other_turret.turret_range)) || turret_turf == other_turret_turf))
                LAZYADD(close_turrets[turret], other_turret)
                LAZYADD(close_turrets[other_turret], turret)

#define ASSESS_LIVING 1
#define ASSESS_CLOSET 2

/datum/controller/subsystem/processing/turrets/proc/find_targets()
    clear_targets(processing)
    var/list/turrets_to_check = processing.Copy()

    while(turrets_to_check.len)
        var/list/combined_view = combined_views(close_turrets[turrets_to_check[turrets_to_check.len]])

        for(var/A in combined_view) 
            var/assess
            if(isliving(A))
                assess = ASSESS_LIVING
            else if(istype(A,/obj/structure/closet))
                assess = ASSESS_CLOSET
            else
                break

            for(var/T in close_turrets[turrets_to_check[turrets_to_check.len]])
                var/obj/machinery/porta_turret/turret = T
                switch(assess)
                    if(ASSESS_LIVING)
                        turret.assess_and_assign_living(A, turret.targets, turret.secondarytargets)
                    if(ASSESS_CLOSET)
                        turret.assess_and_assign_closet(A, turret.targets, turret.secondarytargets)

        for(var/checked_turret in turrets_to_check[turrets_to_check.len])
            turrets_to_check -= checked_turret

#undef ASSESS_LIVING
#undef ASSESS_CLOSET

/datum/controller/subsystem/processing/turrets/proc/combined_views(var/list/turrets)
    . = list()
    for(var/T in turrets)
        var/obj/machinery/porta_turret/turret = T
        . |= view(turret, turret.turret_range)

/datum/controller/subsystem/processing/turrets/proc/clear_targets(var/list/turrets)
    for(var/T in turrets)
        var/obj/machinery/porta_turret/turret = T
        turret.targets.Cut()
        turret.secondarytargets.Cut()