/datum/gas_mixture/immutable/planetary/vore_belly
	initial_temperature = T20C
	initial_gas = list(/datum/gas/oxygen = list(22, 22), /datum/gas/nitrogen = list(82, 82))

/obj/vbelly
	name = "belly"
	desc = ""
	invisibility = INVISIBILITY_MAXIMUM
	var/datum/gas_mixture/immutable/planetary/vore_belly/air_contents = new()
	var/datum/vore_belly/belly_datum

/obj/vbelly/Initialize(mapload, datum/vore_belly/belly)
	. = ..()
	if (!belly)
		return INITIALIZE_HINT_QDEL
	belly_datum = belly

/obj/vbelly/Destroy()
	belly_datum.proxy_destroy()
	. = ..()

//people don't want to have to wear internals while inside someone
//todo: should REALLY find a better way to do this
/obj/vbelly/assume_air(datum/gas_mixture/giver)
	return air_contents.merge(giver)
/obj/vbelly/return_air()
	return air_contents
/obj/vbelly/return_analyzable_air()
	return air_contents
/obj/vbelly/remove_air(amount)
	return air_contents.remove(amount)

/obj/vbelly/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	belly_datum.proxy_entered(arrived, old_loc, old_locs)

/obj/vbelly/Exited(atom/movable/gone, direction)
	. = ..()
	belly_datum.proxy_exited(gone, direction)

/obj/vbelly/drop_location()
	if (belly_datum.owner)
		return belly_datum.owner.drop_location()
	if (SSjob.latejoin_trackers.len)
		return pick(SSjob.latejoin_trackers)
	return SSjob.get_last_resort_spawn_points()

/obj/vbelly/AllowDrop()
	return TRUE

/obj/vbelly/AllowClick()
	return TRUE
