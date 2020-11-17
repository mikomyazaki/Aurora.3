/*		Portable Turrets:
		Constructed from metal, a gun of choice, and a prox sensor.
		This code is slightly more documented than normal, as requested by XSI on IRC.
*/


#define TURRET_PRIORITY_TARGET 2
#define TURRET_SECONDARY_TARGET 1
#define TURRET_NOT_TARGET 0

#define BUILD_STEP_INITIAL 0
#define BUILD_STEP_BOLTS_SECURE 1
#define BUILD_STEP_ARMORED 2
#define BUILD_STEP_ARMOR_BOLTED 3
#define BUILD_STEP_GUN_INSTALLED 4
#define BUILD_STEP_HATCH_CLOSED 5
#define BUILD_STEP_EXTERIOR_ARMOR 6
#define BUILD_STEP_EXTERIOR_ARMOR_WELD 7
#define BUILD_STEP_COMPLETE 8

/obj/machinery/porta_turret
	name = "turret"
	icon = 'icons/obj/turrets.dmi'
	icon_state = "cover_0"
	anchored = TRUE

	density = 0
	use_power = 1				//this turret uses and requires power
	idle_power_usage = 50		//when inactive, this turret takes up constant 50 Equipment power
	active_power_usage = 300	//when active, this turret takes up constant 300 Equipment power
	power_channel = EQUIP	//drains power from the EQUIPMENT channel

	req_one_access = list(access_security, access_heads)

	var/raised = FALSE		//if the turret cover is "open" and the turret is raised
	var/raising= FALSE		//if the turret is currently opening or closing its cover
	var/health = 80			//the turret's health
	var/maxhealth = 80		//turrets maximal health.
	var/auto_repair = 0		//if 1 the turret slowly repairs itself.
	var/locked = TRUE		//if the turret's behaviour control access is locked
	var/controllock = FALSE	//if the turret responds to control panels

	var/obj/item/gun/energy/installation = /obj/item/gun/energy/gun //the type of weapon installed
	var/gun_charge = 0		//the charge of the gun inserted
	var/reqpower = 500		//holder for power needed
	var/lethal_icon = 0		//holder for the icon_state. 1 for lethal sprite, null for stun sprite.
	var/egun = 1			//holder to handle certain guns switching modes
	var/sprite_set = "carbine"	//set of gun sprites the turret will use
	var/cover_set = 0		//set of cover sprites the turret will use
	var/name_override = FALSE

	var/last_fired = 0		//1: if the turret is cooling down from a shot, 0: turret is ready to fire
	var/shot_delay = 15		//1.5 seconds between each shot

	var/check_arrest = TRUE	//checks if the perp is set to arrest
	var/check_records = TRUE//checks if a security record exists at all
	var/check_weapons = FALSE	//checks if it can shoot people that have a weapon they aren't authorized to have
	var/check_access = TRUE	//if this is active, the turret shoots everything that does not meet the access requirements
	var/check_wildlife = TRUE	//checks if it can shoot at simple animals or anything that passes issmall
	var/check_synth	 = FALSE 	//if active, will shoot at anything not an AI or cyborg
	var/ailock = FALSE 			// AI cannot use this

	var/immobile = FALSE	// If TRUE, the turret cannot be detached from the ground with a wrench.
	var/no_salvage = FALSE	// If TRUE, the turret cannot be salvaged for parts when broken.

	var/attacked = FALSE		//if set to 1, the turret gets pissed off and shoots at people nearby (unless they have sec access!)

	var/enabled = TRUE			//determines if the turret is on
	var/lethal = FALSE			//whether in lethal or stun mode
	var/disabled = FALSE

	var/projectile = /obj/item/projectile/beam/stun	//holder for stun (main) mode beam
	var/eprojectile = /obj/item/projectile/beam		//holder for lethal (secondary) mode beam

	var/shot_sound = 'sound/weapons/Taser.ogg'		//what sound should play when the turret fires
	var/eshot_sound	= 'sound/weapons/laser1.ogg'		//what sound should play when the lethal turret fires

	var/datum/effect_system/sparks/spark_system		//the spark system, used for generating... sparks?

	var/wrenching = FALSE
	var/last_target			//last target fired at, prevents turrets from erratically firing at all valid targets in range
	var/list/targets = list()			//list of primary targets
	var/list/secondarytargets = list()	//targets that are least important
	var/resetting = FALSE
	var/fast_processing = FALSE

/obj/machinery/porta_turret/examine(mob/user)
	..()
	var/msg = ""
	if(!health)
		msg += SPAN_DANGER("\The [src] is destroyed!")
	else if(health / maxhealth < 0.35)
		msg += SPAN_DANGER("\The [src] is critically damaged!")
	else if(health / maxhealth < 0.6)
		msg += SPAN_WARNING("\The [src] is badly damaged!")
	else if(health / maxhealth < 1)
		msg += SPAN_NOTICE("\The [src] is slightly damaged!")
	else
		msg += SPAN_GOOD("\The [src] is not damaged!")
	to_chat(user, msg)

/obj/machinery/porta_turret/crescent
	enabled = FALSE
	ailock = TRUE
	check_synth	 = FALSE
	check_access = TRUE
	check_arrest = TRUE
	check_records = TRUE
	check_weapons = TRUE
	check_wildlife = TRUE
	immobile = TRUE
	no_salvage = TRUE
	req_one_access = list(access_cent_specops, access_cent_general)

	var/admin_emag_override = FALSE	// Set to true to allow emagging of this turret.

/obj/machinery/porta_turret/crescent/emag_act()
	if (admin_emag_override)
		return ..()
	else
		return NO_EMAG_ACT

/obj/machinery/porta_turret/stationary
	ailock = TRUE
	lethal = TRUE
	lethal_icon = TRUE
	egun = FALSE
	installation = /obj/item/gun/energy/laser
	sprite_set = "laser"

/obj/machinery/porta_turret/Initialize(mapload)
	. = ..()
	//Sets up a spark system
	spark_system = bind_spark(src, 5)
	if(!istype(installation, /obj/item/gun/energy))
		installation = new installation(src)
	if(installation)
		if(installation.fire_delay_wielded > 0)
			shot_delay = max(installation.fire_delay_wielded, 4)
		else
			shot_delay = max(installation.fire_delay, 4)
		if(!name_override)
			name = "[installation.name] [name]"

	var/area/control_area = get_area(src)
	if(istype(control_area))
		LAZYADD(control_area.turrets, src)
		if(!mapload)
			for(var/control in control_area.turret_controls)
				var/obj/machinery/turretid/aTurretID = control
				aTurretID.turretModes()
		if(LAZYLEN(control_area.turret_controls))
			var/obj/machinery/turretid/SOME_TURRET_ID = control_area.turret_controls[1]
			var/datum/turret_checks/SOME_TC = SOME_TURRET_ID.getState() // this helper should honestly fucking exist why doesn't it :ree:
			if(SOME_TC.lethal != lethal && !egun)
				SOME_TC.enabled = FALSE
			src.setState(SOME_TC)
	START_PROCESSING(SSprocessing, src)

/obj/machinery/porta_turret/Destroy()
	var/area/control_area = get_area(src)
	if(istype(control_area))
		LAZYREMOVE(control_area.turrets, src)
		for(var/turret_control in control_area.turret_controls)
			var/obj/machinery/turretid/aTurretID = turret_control
			aTurretID.turretModes()
	qdel(spark_system)
	spark_system = null
	if(fast_processing)
		STOP_PROCESSING(SSfast_process, src)
	else
		STOP_PROCESSING(SSprocessing, src)

	. = ..()

/obj/machinery/porta_turret/update_icon()
	cut_overlays()
	underlays.Cut()

	if(stat & BROKEN)
		icon_state = "turret_[sprite_set]_broken"
		underlays += "cover_open_[cover_set]"
	else if(raised || raising)
		if(powered() && enabled)
			if(!lethal_icon)
				icon_state = "turret_[sprite_set]_stun"
				underlays += "cover_open_[cover_set]"
			else
				icon_state = "turret_[sprite_set]_lethal"
				underlays += "cover_open_[cover_set]"
		else
			icon_state = "turret_[sprite_set]_off"
			underlays += "cover_open_[cover_set]"
	else
		icon_state = "cover_[cover_set]"

/obj/machinery/porta_turret/proc/isLocked(mob/user)
	if(ailock && issilicon(user))
		to_chat(user, SPAN_WARNING("There seems to be a firewall preventing you from accessing this device."))
		return TRUE

	if(!issilicon(user))
		if(locked && !allowed(user))
			to_chat(user, SPAN_WARNING("Access denied."))
			return TRUE

	return FALSE

/obj/machinery/porta_turret/attack_ai(mob/user)
	if(!ai_can_interact(user))
		return
	ui_interact(user)

/obj/machinery/porta_turret/attack_hand(mob/user)
	ui_interact(user)

/obj/machinery/porta_turret/vueui_data_change(var/list/data, var/mob/user, var/datum/vueui/ui)
	. = ..()
	data = . || data
	if(!data)
		data = list()
	VUEUI_SET_CHECK(data["locked"], locked, ., data)
	VUEUI_SET_CHECK(data["enabled"], enabled, ., data)
	VUEUI_SET_CHECK(data["is_lethal"], TRUE, ., data)
	VUEUI_SET_CHECK(data["lethal"], lethal, ., data)
	VUEUI_SET_CHECK(data["can_switch"], egun, ., data)

	var/usedSettings = list(
		"check_synth" = "Neutralize All Non-Synthetics",
		"check_wildlife" = "Neutralize All Wildlife",
		"check_weapons" = "Check Weapon Authorization",
		"check_records" = "Check Security Records",
		"check_arrest" = "Check Arrest Status",
		"check_access" = "Check Access Authorization"
	)
	VUEUI_SET_IFNOTSET(data["settings"], list(), ., data)
	for(var/v in usedSettings)
		var/name = usedSettings[v]
		VUEUI_SET_IFNOTSET(data["settings"][v], list(), ., data)
		data["settings"][v]["category"] = name
		VUEUI_SET_CHECK(data["settings"][v]["value"], vars[v], ., data)


/obj/machinery/porta_turret/ui_interact(mob/user)
	var/datum/vueui/ui = SSvueui.get_open_ui(user, src)
	if (!ui)
		ui = new(user, src, "turrets-control", 375, 725, "Turret Controls")
	ui.open()

/obj/machinery/porta_turret/proc/HasController()
	var/area/A = get_area(src)
	return A && A.turret_controls.len

/obj/machinery/porta_turret/CanUseTopic(var/mob/user)
	if(HasController())
		to_chat(user, SPAN_NOTICE("Turrets can only be controlled using the assigned turret controller."))
		return STATUS_CLOSE

	if(isLocked(user))
		return STATUS_CLOSE

	if(!anchored)
		to_chat(usr, SPAN_NOTICE("\The [src] has to be secured first!"))
		return STATUS_CLOSE

	return ..()

/obj/machinery/porta_turret/Topic(href, href_list)
	if(href_list["command"] && !isnull(href_list["value"]))
		var/value = text2num(href_list["value"])
		if(href_list["command"] == "enable")
			enabled = value
			if (enabled)
				START_PROCESSING(SSprocessing, src)
				fast_processing = FALSE
			else if(fast_processing)
				STOP_PROCESSING(SSfast_process, src)
				fast_processing = FALSE
				popDown()
			else
				STOP_PROCESSING(SSprocessing, src)
				popDown()
		else if(href_list["command"] == "lethal")
			lethal = value
			lethal_icon = value
		else if(href_list["command"] == "check_synth")
			check_synth = value
		else if(href_list["command"] == "check_weapons")
			check_weapons = value
		else if(href_list["command"] == "check_records")
			check_records = value
		else if(href_list["command"] == "check_arrest")
			check_arrest = value
		else if(href_list["command"] == "check_access")
			check_access = value
		else if(href_list["command"] == "check_wildlife")
			check_wildlife = value
		SSvueui.check_uis_for_change(src)
		return 1

/obj/machinery/porta_turret/power_change()
	..()
	if(powered())
		queue_icon_update()
	else
		addtimer(CALLBACK(src, .proc/lose_power), rand(1, 15))

/obj/machinery/porta_turret/proc/lose_power()
	stat |= NOPOWER
	queue_icon_update()

/obj/machinery/porta_turret/attackby(obj/item/I, mob/user)
	if(stat & BROKEN)
		if(I.iscrowbar())
			//If the turret is destroyed, you can remove it with a crowbar to
			//try and salvage its components
			to_chat(user, SPAN_NOTICE("You begin prying the metal coverings off."))
			if(do_after(user, 20/I.toolspeed))
				if(prob(70) && !no_salvage)
					to_chat(user, SPAN_NOTICE("You remove the turret and salvage some components."))
					if(installation)
						installation.forceMove(loc)
						installation = null
					if(prob(50))
						new /obj/item/stack/material/steel(loc, rand(1,4))
					if(prob(50))
						new /obj/item/device/assembly/prox_sensor(loc)
				else
					to_chat(user, SPAN_NOTICE("You remove the turret but did not manage to salvage anything."))
				qdel(src) // qdel

	else if((I.iswrench()))
		if (immobile)
			to_chat(user, SPAN_NOTICE("[src] is firmly attached to the ground with some form of epoxy."))
			return

		if(enabled || raised)
			to_chat(user, SPAN_WARNING("You cannot unsecure an active turret!"))
			return
		if(wrenching)
			to_chat(user, SPAN_WARNING("Someone is already [anchored ? "un" : ""]securing the turret!"))
			return
		if(!anchored && isinspace())
			to_chat(user, SPAN_WARNING("Cannot secure turrets in space!"))
			return

		user.visible_message( \
				SPAN_WARNING("[user] begins [anchored ? "un" : ""]securing the turret."), \
				SPAN_NOTICE("You begin [anchored ? "un" : ""]securing the turret.") \
			)

		wrenching = TRUE
		if(do_after(user, 50/I.toolspeed))
			//This code handles moving the turret around. After all, it's a portable turret!
			if(!anchored)
				playsound(loc, I.usesound, 100, 1)
				anchored = TRUE
				update_icon()
				to_chat(user, SPAN_NOTICE("You secure the exterior bolts on the turret."))
			else if(anchored)
				playsound(loc, I.usesound, 100, 1)
				anchored = FALSE
				to_chat(user, SPAN_NOTICE("You unsecure the exterior bolts on the turret."))
				update_icon()
		wrenching = FALSE

	else if(I.GetID())
		//Behavior lock/unlock mangement
		if(allowed(user))
			locked = !locked
			to_chat(user, SPAN_NOTICE("Controls are now [locked ? "locked" : "unlocked"]."))
			updateUsrDialog()
		else
			to_chat(user, SPAN_NOTICE("Access denied."))

	else if(I.iswelder())
		var/obj/item/weldingtool/WT = I
		if (!WT.welding)
			to_chat(user, SPAN_DANGER("\The [WT] must be turned on!"))
			return
		else if (health == maxhealth)
			to_chat(user, SPAN_NOTICE("\The [src] is fully repaired."))
			return
		else if (WT.remove_fuel(3, user))
			to_chat(user, SPAN_NOTICE("Now welding \the [src]."))
			if(do_after(user, 5))
				if(QDELETED(src) || !WT.isOn())
					return
				playsound(src.loc, 'sound/items/welder_pry.ogg', 50, 1)
				health += maxhealth / 3
				health = min(maxhealth, health)
				return
			else
				to_chat(user, SPAN_NOTICE("You fail to complete the welding."))
		else
			to_chat(user, SPAN_WARNING("You need more welding fuel to complete this task."))
			return 1
	else
		//if the turret was attacked with the intention of harming it:
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		take_damage(I.force * 0.5)
		if(I.force * 0.5 > 1) //if the force of impact dealt at least 1 damage, the turret gets pissed off
			if(!attacked && !emagged)
				attacked = 1
				addtimer(CALLBACK(src, .proc/reset_attacked), 1 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE)
		..()

/obj/machinery/porta_turret/proc/reset_attacked()
	attacked = FALSE

/obj/machinery/porta_turret/emag_act(var/remaining_charges, var/mob/user)
	if(!emagged)
		//Emagging the turret makes it go bonkers and stun everyone. It also makes
		//the turret shoot much, much faster.
		to_chat(user, SPAN_WARNING("You short out [src]'s threat assessment circuits."))
		visible_message("[src] hums oddly...")
		emagged = TRUE
		lethal_icon = TRUE
		controllock = TRUE
		shot_delay = shot_delay / 2
		enabled = FALSE //turns off the turret temporarily
		sleep(6 SECONDS) //6 seconds for the traitor to gtfo of the area before the turret decides to ruin his shit
		enabled = TRUE //turns it back on. The cover popUp() popDown() are automatically called in process(), no need to define it here
		return TRUE

/obj/machinery/porta_turret/proc/take_damage(var/force)
	if(!raised || !raising)
		force = force / 8
		if(force < 5)
			return

	health -= force
	if (force > 5 && prob(45))
		spark_system.queue()
	if(health <= 0)
		die()	//the death process :(

/obj/machinery/porta_turret/bullet_act(obj/item/projectile/Proj)
	var/damage = Proj.get_structure_damage()

	if(!damage)
		return

	if(enabled)
		if(!attacked && !emagged)
			attacked = TRUE
			addtimer(CALLBACK(src, .proc/reset_attacked), 6 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE)
	..()

	take_damage(damage)

/obj/machinery/porta_turret/emp_act(severity)
	if(enabled)
		//if the turret is on, the EMP no matter how severe disables the turret for a while
		//and scrambles its settings, with a slight chance of having an emag effect
		check_arrest = prob(50)
		check_records = prob(50)
		check_weapons = prob(50)
		check_access = prob(20)	// check_access is a pretty big deal, so it's least likely to get turned on
		check_wildlife = prob(50)
		if(prob(5))
			emagged = TRUE

		enabled = FALSE
		addtimer(CALLBACK(src, .proc/post_emp_act), rand(6 SECONDS, 60 SECONDS))

	..()

/obj/machinery/porta_turret/proc/post_emp_act()
	enabled = TRUE

/obj/machinery/porta_turret/ex_act(severity)
	switch (severity)
		if (1)
			qdel(src)
		if (2)
			if (prob(25))
				qdel(src)
			else
				take_damage(initial(health) * 8) //should instakill most turrets
		if (3)
			take_damage(initial(health) * 8 / 3)

/obj/machinery/porta_turret/proc/die()	//called when the turret dies, ie, health <= 0
	health = 0
	stat |= BROKEN	//enables the BROKEN bit
	spark_system.queue()	//creates some sparks because they look cool
	update_icon()

/obj/machinery/porta_turret/process()
	//the main machinery process
	if(stat & (NOPOWER|BROKEN))
		//if the turret has no power or is broken, make the turret pop down if it hasn't already
		popDown()
		return

	if(!enabled)
		//if the turret is off, make it pop down
		popDown()
		return

	targets = list()
	secondarytargets = list()

	for(var/v in view(world.view, src))
		if(isliving(v))
			assess_and_assign_living(v, targets, secondarytargets)
		else if(istype(v, /obj/structure/closet))
			assess_and_assign_closet(v, targets, secondarytargets)

	if(!tryToShootAt(targets))
		if(!tryToShootAt(secondarytargets) && !resetting) // if no valid targets, go for secondary targets
			if(raised || raising) // we've already reset
				resetting = TRUE
				addtimer(CALLBACK(src, .proc/reset), 6 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE) // no valid targets, close the cover

	if(targets.len || secondarytargets.len)
		if(!fast_processing)
			STOP_PROCESSING(SSprocessing, src)
			START_PROCESSING(SSfast_process, src)
			fast_processing = TRUE
	else
		if(fast_processing)
			STOP_PROCESSING(SSfast_process, src)
			START_PROCESSING(SSprocessing, src)
			fast_processing = FALSE

	if(auto_repair && (health < maxhealth))
		use_power(20000)
		health = min(health+1, maxhealth) // 1HP for 20kJ

/obj/machinery/porta_turret/proc/reset()
	if(!targets.len && !secondarytargets.len)
		popDown()
	resetting = FALSE

/obj/machinery/porta_turret/proc/assess_and_assign_living(var/mob/living/L, var/list/targets, var/list/secondarytargets)
	switch(assess_living(L))
		if(TURRET_PRIORITY_TARGET)
			targets += L
		if(TURRET_SECONDARY_TARGET)
			secondarytargets += L

/obj/machinery/porta_turret/proc/assess_and_assign_closet(var/obj/structure/closet/C, var/list/targets, var/list/secondarytargets)
	if(istype(C) && is_type_in_list(C,list(/obj/structure/closet/statue,/obj/structure/closet/hydrant,/obj/structure/closet/walllocker)))
		return
	if(!lethal)
		return

	//If someone in the locker is a primary target, we assign the locker as a primary target and return immediately.
	//If someone in the locker is a secondary target, we remember that and only assign the locker as a secondary target, if there is no other primary target in the locker.
	var/found_secondary = FALSE
	for(var/O in C.contents)
		if(!isliving(O))
			continue
		switch(assess_living(O))
			if(TURRET_PRIORITY_TARGET)
				targets += C
				return
			if(TURRET_SECONDARY_TARGET)
				found_secondary = TRUE
	if(found_secondary)
		secondarytargets += C

/obj/machinery/porta_turret/proc/assess_living(var/mob/living/L)
	if(!istype(L))
		return TURRET_NOT_TARGET

	if(!L)
		return TURRET_NOT_TARGET

	if(L.invisibility >= INVISIBILITY_LEVEL_ONE) // Cannot see him. see_invisible is a mob-var
		return TURRET_NOT_TARGET

	if(!emagged && issilicon(L))	// Don't target silica
		return TURRET_NOT_TARGET

	if(L.stat && !emagged)		//if the perp is dead/dying, no need to bother really
		return TURRET_NOT_TARGET	//move onto next potential victim!

	if(get_dist(src, L) > world.view)	//if it's too far away, why bother?
		return TURRET_NOT_TARGET

	var/flags =  PASSTABLE|PASSTRACE
	if(ispath(projectile, /obj/item/projectile/beam) || ispath(eprojectile, /obj/item/projectile/beam))
		flags |= PASSTABLE|PASSGLASS|PASSGRILLE

	if(!(L in check_trajectory(L, src, pass_flags=flags)))	//check if we have true line of sight
		return TURRET_NOT_TARGET

	if(emagged)		// If emagged not even the dead get a rest
		return L.stat ? TURRET_SECONDARY_TARGET : TURRET_PRIORITY_TARGET

	if(lethal && locate(/mob/living/silicon/ai) in get_turf(L))		//don't accidentally kill the AI!
		return TURRET_NOT_TARGET

	if(check_synth)	//If it's set to attack all non-silicons, target them!
		if(L.lying)
			return lethal ? TURRET_SECONDARY_TARGET : TURRET_NOT_TARGET
		return TURRET_PRIORITY_TARGET

	if(iscuffed(L)) // If the target is handcuffed, leave it alone
		return TURRET_NOT_TARGET

	if(isanimal(L) || issmall(L)) // Animals are not so dangerous
		return check_wildlife ? TURRET_SECONDARY_TARGET : TURRET_NOT_TARGET

	if(isalien(L)) // Xenos are dangerous
		return check_wildlife ? TURRET_PRIORITY_TARGET	: TURRET_NOT_TARGET

	if(ishuman(L))	//if the target is a human, analyze threat level
		if(assess_perp(L) < 4)
			return TURRET_NOT_TARGET	//if threat level < 4, keep going

	if(L.lying)		//if the perp is lying down, it's still a target but a less-important target
		return lethal ? TURRET_SECONDARY_TARGET : TURRET_NOT_TARGET

	if(ismech(L))
		var/mob/living/heavy_vehicle/M = L
		if(!M.pilots?.len)
			return TURRET_NOT_TARGET
		for(var/mob/pilot in M.pilots)
			if(allowed(pilot)) // don't shoot if the mech contains at least one person with access
				return TURRET_NOT_TARGET
	return TURRET_PRIORITY_TARGET	//if the perp has passed all previous tests, congrats, it is now a "shoot-me!" nominee

/obj/machinery/porta_turret/proc/assess_perp(var/mob/living/carbon/human/H)
	if(!H || !istype(H))
		return 0

	if(emagged)
		return 10

	return H.assess_perp(src, check_access, check_weapons, check_records, check_arrest)

/obj/machinery/porta_turret/proc/tryToShootAt(var/list/targets)
	if(targets.len && last_target && (last_target in targets) && target(last_target))
		return TRUE

	while(targets.len)
		var/T = pick(targets)
		targets -= T
		if(target(T))
			return TRUE

/obj/machinery/porta_turret/proc/popUp()	//pops the turret up
	set waitfor = FALSE
	if(disabled)
		return
	if(raising || raised)
		return
	if(stat & BROKEN)
		return
	set_raised_raising(raised, TRUE)
	update_icon()

	var/atom/flick_holder = new /atom/movable/porta_turret_cover(loc)
	flick_holder.layer = layer + 0.1
	flick("popup_[cover_set]", flick_holder)
	playsound(loc, 'sound/machines/turrets/turret_deploy.ogg', 100, 1)
	sleep(1 SECOND)
	qdel(flick_holder)

	set_raised_raising(TRUE, FALSE)
	update_icon()

/obj/machinery/porta_turret/proc/popDown()	//pops the turret down
	set waitfor = FALSE

	last_target = null
	if(disabled)
		return
	if(raising || !raised)
		return
	if(stat & BROKEN)
		return
	set_raised_raising(raised, TRUE)

	var/atom/flick_holder = new /atom/movable/porta_turret_cover(loc)
	flick_holder.layer = layer + 0.1
	flick("popdown_[cover_set]", flick_holder)
	playsound(loc, 'sound/machines/turrets/turret_retract.ogg', 100, 1)
	sleep(1 SECOND)
	qdel(flick_holder)

	set_raised_raising(FALSE, FALSE)
	update_icon()

/obj/machinery/porta_turret/proc/set_raised_raising(var/raised, var/raising)
	src.raised = raised
	src.raising = raising
	density = raised || raising

/obj/machinery/porta_turret/proc/target(var/target)
	if(disabled)
		return FALSE
	if(target)
		last_target = target
		popUp()				//pop the turret up if it's not already up.
		var/d = get_dir(src, target)	//even if you can't shoot, follow the target
		if(d != dir)
			set_dir(d)
			playsound(loc, 'sound/machines/turrets/turret_rotate.ogg', 100, 1)
		shootAt(target)
		return TRUE
	return FALSE

/obj/machinery/porta_turret/proc/reset_last_fired()
	last_fired = FALSE

/obj/machinery/porta_turret/proc/shootAt(var/target)
	//any emagged turrets will shoot extremely fast! This not only is deadly, but drains a lot power!
	if(last_fired || !raised)	//prevents rapid-fire shooting, unless it's been emagged
		return

	var/turf/T = get_turf(src)
	var/turf/U = get_turf(target)
	if(!istype(T) || !istype(U))
		return

	update_icon()
	var/obj/item/projectile/A

	if(emagged || lethal)
		A = new eprojectile(loc)
		playsound(loc, eshot_sound, 75, 1)
	else
		A = new projectile(loc)
		playsound(loc, shot_sound, 75, 1)

	A.accuracy = max(installation.accuracy * 0.25 , installation.accuracy_wielded * 0.25, A.accuracy * 0.25)  // Because turrets should be better at shooting.

	// Lethal/emagged turrets use twice the power due to higher energy beams
	// Emagged turrets again use twice as much power due to higher firing rates
	use_power(reqpower * (2 * (emagged || lethal)) * (2 * emagged))

	//Turrets aim for the center of mass by default.
	//If the target is grabbing someone then the turret smartly aims for extremities
	var/def_zone = get_exposed_defense_zone(target)
	//Shooting Code:
	A.launch_projectile(target, def_zone)
	last_fired = TRUE
	addtimer(CALLBACK(src, .proc/reset_last_fired), shot_delay, TIMER_UNIQUE | TIMER_OVERRIDE)

/datum/turret_checks
	var/enabled
	var/lethal
	var/check_synth
	var/check_access
	var/check_records
	var/check_arrest
	var/check_weapons
	var/check_wildlife
	var/ailock

/obj/machinery/porta_turret/proc/setState(var/datum/turret_checks/TC)
	if(controllock)
		return
	src.enabled = TC.enabled
	if (enabled)
		START_PROCESSING(SSprocessing, src)
		fast_processing = FALSE
	else if(fast_processing)
		STOP_PROCESSING(SSprocessing, src)
		fast_processing = FALSE
	else
		STOP_PROCESSING(SSfast_process, src)
	if(egun) //If turret can switch modes.
		src.lethal = TC.lethal
		src.lethal_icon = TC.lethal

	check_synth = TC.check_synth
	check_access = TC.check_access
	check_records = TC.check_records
	check_arrest = TC.check_arrest
	check_weapons = TC.check_weapons
	check_wildlife = TC.check_wildlife
	ailock = TC.ailock

	src.power_change()
	update_icon()

/*
		Portable turret constructions
		Known as "turret frame"s
*/

/obj/machinery/porta_turret_construct
	name = "turret frame"
	icon = 'icons/obj/turrets.dmi'
	icon_state = "turret_frame_0_0"
	density = TRUE
	var/target_type = /obj/machinery/porta_turret	// The type we intend to build
	var/build_step = BUILD_STEP_INITIAL			//the current step in the building process
	var/finish_name = "turret"	//the name applied to the product turret
	var/obj/item/gun/energy/installation = null		//the gun type installed
	var/case_sprite_set = 0		//sprite set the turret case will use
	var/obj/item/gun/energy/E = null

/obj/machinery/porta_turret_construct/dark
	icon_state = "turret_frame_0_1"
	case_sprite_set = 1

/obj/machinery/porta_turret_construct/attackby(obj/item/I, mob/user)
	//this is a bit unwieldy but self-explanatory
	switch(build_step)
		if(BUILD_STEP_INITIAL)	//first step
			if(I.iswrench() && !anchored)
				playsound(loc, I.usesound, 100, 1)
				to_chat(user, SPAN_NOTICE("You secure the external bolts."))
				anchored = TRUE
				build_step = BUILD_STEP_BOLTS_SECURE
				icon_state = "turret_frame_1_[case_sprite_set]"
				return

			else if(I.iscrowbar() && !anchored)
				playsound(loc, I.usesound, 75, 1)
				to_chat(user, SPAN_NOTICE("You dismantle the turret construction."))
				new /obj/item/stack/material/steel( loc, 5)
				qdel(src)
				return

		if(BUILD_STEP_BOLTS_SECURE)
			if(istype(I, /obj/item/stack/material) && I.get_material_name() == DEFAULT_WALL_MATERIAL)
				var/obj/item/stack/M = I
				if(M.use(2))
					to_chat(user, SPAN_NOTICE("You add some metal armor to the interior frame."))
					build_step = BUILD_STEP_ARMORED
					icon_state = "turret_frame_2_[case_sprite_set]"
				else
					to_chat(user, SPAN_WARNING("You need two sheets of metal to continue construction."))
				return

			else if(I.iswrench())
				playsound(loc, I.usesound, 75, 1)
				to_chat(user, SPAN_NOTICE("You unfasten the external bolts."))
				anchored = FALSE
				build_step = BUILD_STEP_INITIAL
				icon_state = "turret_frame_0_[case_sprite_set]"
				return

		if(BUILD_STEP_ARMORED)
			if(I.iswrench())
				playsound(loc, I.usesound, 100, 1)
				to_chat(user, SPAN_NOTICE("You bolt the metal armor into place."))
				build_step = BUILD_STEP_ARMOR_BOLTED
				icon_state = "turret_frame_3_[case_sprite_set]"
				return

			else if(I.iswelder())
				var/obj/item/weldingtool/WT = I
				if(!WT.isOn())
					return
				if(WT.get_fuel() < 5) //uses up 5 fuel.
					to_chat(user, SPAN_NOTICE("You need more fuel to complete this task."))
					return

				playsound(loc, pick('sound/items/welder.ogg', 'sound/items/welder_pry.ogg'), 50, 1)
				if(do_after(user, 20/I.toolspeed))
					if(!src || !WT.remove_fuel(5, user)) 
						return
					build_step = BUILD_STEP_BOLTS_SECURE
					to_chat(user, "You remove the turret's interior metal armor.")
					new /obj/item/stack/material/steel(loc, 2)
					icon_state = "turret_frame_1_[case_sprite_set]"
					return


		if(BUILD_STEP_ARMOR_BOLTED)
			if(istype(I, /obj/item/gun/energy)) //the gun installation part
				E = I //typecasts the item to a gun
				if(E.can_turret)
					if(isrobot(user))
						return
					if(!user.unEquip(I))
						to_chat(user, SPAN_NOTICE("\the [I] is stuck to your hand, you cannot put it in \the [src]"))
						return
					to_chat(user, SPAN_NOTICE("You install [I] into the turret."))
					user.drop_from_inventory(E,src)
					target_type = /obj/machinery/porta_turret
					installation = I //installation becomes I.type
					build_step = BUILD_STEP_GUN_INSTALLED
					icon_state = "turret_frame_4_[case_sprite_set]"
					add_overlay("turret_[E.turret_sprite_set]_off")
					return

			else if(I.iswrench())
				playsound(loc, I.usesound, 100, 1)
				to_chat(user, SPAN_NOTICE("You remove the turret's metal armor bolts."))
				build_step = BUILD_STEP_ARMORED
				icon_state = "turret_frame_2_[case_sprite_set]"
				return

		if(BUILD_STEP_GUN_INSTALLED)
			if(isprox(I))
				build_step = BUILD_STEP_HATCH_CLOSED
				if(!user.unEquip(I))
					to_chat(user, SPAN_NOTICE("\the [I] is stuck to your hand, you cannot put it in \the [src]"))
					return
				to_chat(user, SPAN_NOTICE("You add the prox sensor to the turret."))
				qdel(I)
				return

			//attack_hand() removes the gun

		if(BUILD_STEP_HATCH_CLOSED)
			if(I.isscrewdriver())
				playsound(loc, I.usesound, 100, 1)
				build_step = BUILD_STEP_EXTERIOR_ARMOR
				to_chat(user, SPAN_NOTICE("You close the access hatch."))
				icon_state = "turret_frame_5a_[case_sprite_set]"
				add_overlay("turret_[E.turret_sprite_set]_off")
				add_overlay("turret_frame_5b_[case_sprite_set]")
				return

			//attack_hand() removes the prox sensor

		if(BUILD_STEP_EXTERIOR_ARMOR)
			if(istype(I, /obj/item/stack/material) && I.get_material_name() == DEFAULT_WALL_MATERIAL)
				var/obj/item/stack/M = I
				if(M.use(2))
					to_chat(user, SPAN_NOTICE("You add some metal armor to the exterior frame."))
					cut_overlays()
					icon_state = "turret_frame_5a_[case_sprite_set]"
					add_overlay("turret_[E.turret_sprite_set]_off")
					add_overlay("turret_frame_5c_[case_sprite_set]")
					build_step = BUILD_STEP_EXTERIOR_ARMOR_WELD
				else
					to_chat(user, SPAN_WARNING("You need two sheets of metal to continue construction."))
				return

			else if(I.isscrewdriver())
				playsound(loc, I.usesound, 100, 1)
				build_step = BUILD_STEP_HATCH_CLOSED
				to_chat(user, SPAN_NOTICE("You open the access hatch."))
				cut_overlays()
				icon_state = "turret_frame_4_[case_sprite_set]"
				add_overlay("turret_[E.turret_sprite_set]_off")
				return

		if(BUILD_STEP_EXTERIOR_ARMOR_WELD)
			if(I.iswelder())
				var/obj/item/weldingtool/WT = I
				if(!WT.isOn())
					return
				if(WT.get_fuel() < 5)
					to_chat(user, SPAN_NOTICE("You need more fuel to complete this task."))

				playsound(loc, pick('sound/items/welder.ogg', 'sound/items/welder_pry.ogg'), 50, 1)
				if(do_after(user, 30/I.toolspeed))
					if(!src || !WT.remove_fuel(5, user))
						return
					build_step = BUILD_STEP_COMPLETE
					to_chat(user, SPAN_NOTICE("You weld the turret's armor down."))

					//The final step: create a full turret
					var/obj/machinery/porta_turret/Turret = new target_type(loc)
					Turret.name = finish_name
					Turret.installation = installation
					Turret.gun_charge = E.power_supply.charge
					Turret.enabled = FALSE

					Turret.projectile = initial(E.projectile_type)
					if(E.secondary_projectile_type)
						Turret.eprojectile = E.secondary_projectile_type
					else
						Turret.eprojectile = E.projectile_type

					Turret.shot_sound = initial(E.fire_sound)
					if(E.secondary_fire_sound)
						Turret.eshot_sound = E.secondary_fire_sound
					else
						Turret.eshot_sound = E.fire_sound
					Turret.egun = E.can_switch_modes
					Turret.sprite_set = E.turret_sprite_set
					Turret.lethal_icon = E.turret_is_lethal
					// Check if gun has wielded delay, turret will have same fire rate as the gun.
					if(E.fire_delay_wielded > 0)
						Turret.shot_delay = max(E.fire_delay_wielded, 4)
					else
						Turret.shot_delay = max(E.fire_delay, 4)

					Turret.cover_set = case_sprite_set
					Turret.icon_state = "cover_[case_sprite_set]"
					START_PROCESSING(SSprocessing, Turret)
					qdel(src) // qdel

			else if(I.iscrowbar())
				playsound(loc, I.usesound, 75, 1)
				to_chat(user, SPAN_NOTICE("You pry off the turret's exterior armor."))
				new /obj/item/stack/material/steel(loc, 2)
				build_step = BUILD_STEP_EXTERIOR_ARMOR
				cut_overlays()
				icon_state = "turret_frame_5a_[case_sprite_set]"
				add_overlay("turret_[E.turret_sprite_set]_off")
				add_overlay("turret_frame_5c_[case_sprite_set]")
				return

	if(I.ispen())	//you can rename turrets like bots!
		var/t = sanitizeSafe(input(user, "Enter new turret name", name, finish_name) as text, MAX_NAME_LEN)
		if(!t)
			return
		if(!in_range(src, usr) && loc != usr)
			return

		finish_name = t
		return

	..()


/obj/machinery/porta_turret_construct/attack_hand(mob/user)
	switch(build_step)
		if(BUILD_STEP_GUN_INSTALLED)
			if(!installation)
				return
			build_step = BUILD_STEP_ARMOR_BOLTED
			E.forceMove(src.loc)
			installation = null
			cut_overlays()
			icon_state = "turret_frame_3_[case_sprite_set]"
			to_chat(user, SPAN_NOTICE("You remove [E.name] from the turret frame."))

		if(BUILD_STEP_HATCH_CLOSED)
			to_chat(user, SPAN_NOTICE("You remove the prox sensor from the turret frame."))
			new /obj/item/device/assembly/prox_sensor(loc)
			build_step = BUILD_STEP_GUN_INSTALLED

/obj/machinery/porta_turret_construct/attack_ai()
	return

/atom/movable/porta_turret_cover
	icon = 'icons/obj/turrets.dmi'


//preset turrets

/obj/machinery/porta_turret/xray
	installation = /obj/item/gun/energy/xray
	lethal = TRUE
	lethal_icon = TRUE
	egun = FALSE
	sprite_set = "xray"

	eprojectile = /obj/item/projectile/beam/xray
	eshot_sound	= 'sound/weapons/laser3.ogg'
	req_one_access = list(access_syndicate)

/obj/machinery/porta_turret/ion
	installation = /obj/item/gun/energy/rifle/ionrifle
	lethal = TRUE
	lethal_icon = FALSE
	egun = FALSE
	sprite_set = "ion"

	projectile = /obj/item/projectile/ion/stun
	eprojectile = /obj/item/projectile/ion
	shot_sound = 'sound/weapons/laser1.ogg'
	eshot_sound	= 'sound/weapons/laser1.ogg'
	req_one_access = list(access_syndicate)

/obj/machinery/porta_turret/crossbow
	installation = /obj/item/gun/energy/crossbow
	lethal = TRUE
	lethal_icon = TRUE
	egun = FALSE
	sprite_set = "crossbow"

	eprojectile = /obj/item/projectile/energy/bolt/large
	eshot_sound	= 'sound/weapons/genhit.ogg'
	req_one_access = list(access_syndicate)

/obj/machinery/porta_turret/cannon
	installation = /obj/item/gun/energy/rifle/laser/heavy
	lethal = TRUE
	lethal_icon = TRUE
	egun = FALSE
	sprite_set = "cannon"

	eprojectile = /obj/item/projectile/beam/heavylaser
	eshot_sound	= 'sound/weapons/lasercannonfire.ogg'
	req_one_access = list(access_syndicate)

/obj/machinery/porta_turret/pulse
	installation = /obj/item/gun/energy/pulse
	lethal = TRUE
	lethal_icon = TRUE
	egun = FALSE
	sprite_set = "pulse"
	no_salvage = TRUE

	eprojectile = /obj/item/projectile/beam/pulse
	eshot_sound	= 'sound/weapons/pulse.ogg'
	req_one_access = list(access_syndicate)

/obj/machinery/porta_turret/sniper
	installation = /obj/item/gun/energy/sniperrifle
	lethal = TRUE
	lethal_icon = TRUE
	egun = FALSE
	sprite_set = "sniper"
	no_salvage = TRUE

	eprojectile = /obj/item/projectile/beam/sniper
	eshot_sound	= 'sound/weapons/marauder.ogg'
	req_one_access = list(access_syndicate)

/obj/machinery/porta_turret/net
	installation = /obj/item/gun/energy/net
	lethal = TRUE
	lethal_icon = TRUE
	egun = FALSE
	sprite_set = "net"

	eprojectile = /obj/item/projectile/beam/energy_net
	eshot_sound	= 'sound/weapons/plasma_cutter.ogg'
	req_one_access = list(access_syndicate)

/obj/machinery/porta_turret/thermal
	installation = /obj/item/gun/energy/vaurca/thermaldrill
	lethal = TRUE
	lethal_icon = TRUE
	egun = FALSE
	sprite_set = "thermaldrill"

	eprojectile = /obj/item/projectile/beam/thermaldrill
	eshot_sound	= 'sound/magic/lightningbolt.ogg'
	req_one_access = list(access_syndicate)

/obj/machinery/porta_turret/meteor
	installation = /obj/item/gun/energy/meteorgun
	lethal = TRUE
	lethal_icon = TRUE
	egun = FALSE
	sprite_set = "meteor"
	no_salvage = TRUE

	eprojectile = /obj/item/projectile/meteor
	eshot_sound	= 'sound/weapons/lasercannonfire.ogg'
	req_one_access = list(access_syndicate)

/obj/machinery/porta_turret/ballistic
	installation = /obj/item/gun/energy/mountedsmg
	lethal = TRUE
	lethal_icon = TRUE
	egun = FALSE
	sprite_set = "ballistic"
	no_salvage = TRUE

	eprojectile = /obj/item/projectile/bullet/rifle/a762
	eshot_sound	= 'sound/weapons/gunshot/gunshot_saw.ogg'

	req_one_access = list(access_syndicate)

/obj/machinery/porta_turret/legion
	enabled = FALSE
	use_power = 0
	icon_state = "cover_legion"
	lethal = TRUE
	lethal_icon = TRUE
	egun = FALSE
	installation = /obj/item/gun/energy/blaster/carbine
	sprite_set = "blaster"
	cover_set = "legion"
	eprojectile = /obj/item/projectile/energy/blaster/heavy

	check_arrest = FALSE
	check_records = FALSE
	check_access = TRUE
	ailock = TRUE
	req_one_access = list(access_legion)

#undef TURRET_PRIORITY_TARGET
#undef TURRET_SECONDARY_TARGET
#undef TURRET_NOT_TARGET

#undef BUILD_STEP_INITIAL
#undef BUILD_STEP_BOLTS_SECURE
#undef BUILD_STEP_ARMORED
#undef BUILD_STEP_ARMOR_BOLTED
#undef BUILD_STEP_GUN_INSTALLED
#undef BUILD_STEP_HATCH_CLOSED
#undef BUILD_STEP_EXTERIOR_ARMOR
#undef BUILD_STEP_EXTERIOR_ARMOR_WELD
#undef BUILD_STEP_COMPLETE