/datum/vore_belly
	var/name = "belly"
	var/desc = "A belly."
	var/mob/living/owner = null
	var/mode = VORE_MODE_HOLD
	var/can_taste = FALSE
	var/swallow_verb = "nom"
	var/belly_ref
	var/list/data = list()
	var/list/absorbing = list()
	var/list/absorbed = list()
	var/static_data_cooldown = 0 //so we don't send data over and over and over
	var/static_timer = FALSE
	var/belly_string_ref
	var/list/belly_slowdown_refs = list()
	var/obj/vbelly/belly_obj


/datum/vore_belly/New(mob/living/living_owner, list/belly_data, bellynum)
	. = ..()
	if (!isliving(living_owner))
		return INITIALIZE_HINT_QDEL
	owner = living_owner
	RegisterSignal(owner, COMSIG_PARENT_EXAMINE, .proc/on_examine)
	set_data(belly_data, bellynum)
	belly_obj = new(owner, src)
	belly_string_ref = "belly_[ref(belly_obj)]"
	belly_obj.forceMove(owner)

/datum/vore_belly/proc/proxy_destroy()
	mass_release_from_contents()
	for (var/nommed_ref in belly_slowdown_refs)
		owner.remove_movespeed_modifier(nommed_ref)

/datum/vore_belly/Destroy()
	proxy_destroy()
	qdel(belly_obj)
	. = ..()

/datum/vore_belly/proc/set_data(_data, bellynum)
	if(isnull(_data))
		return
	for (var/varname in _data)
		if (!(varname in static_belly_vars()))
			_data -= varname
	var/static/default_belly_list = default_belly_info()
	for (var/varname in default_belly_list)
		if (!(varname in _data))
			_data[varname] = default_belly_list[varname]
	data = _data
	name = data[BELLY_NAME]
	desc = data[BELLY_DESC]
	mode = data[BELLY_MODE]
	can_taste = data[BELLY_CAN_TASTE] == "Yes" ? TRUE : FALSE
	swallow_verb = data[BELLY_SWALLOW_VERB]
	check_mode()
	if (!isnull(bellynum))
		belly_ref = bellynum

/datum/vore_belly/proc/proxy_entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	if (isliving(arrived))
		var/mob/living/arrived_mob = arrived
		if (desc && arrived_mob.check_vore_toggle(SEE_OTHER_MESSAGES, VORE_CHAT_TOGGLES))
			to_chat(arrived_mob, SPAN_NOTICE(desc))
		var/datum/component/vore/vore = arrived_mob.GetComponent(/datum/component/vore)
		if (owner.check_vore_toggle(SEE_OTHER_MESSAGES, VORE_CHAT_TOGGLES) && can_taste)
			to_chat(owner, SPAN_NOTICE("[arrived_mob] tastes of [vore.char_vars["tastes_of"]]."))
		RegisterSignal(arrived, COMSIG_LIVING_RESIST, .proc/prey_resist)
		check_mode()
		arrived_mob.become_blind(belly_string_ref)
	if (iscarbon(arrived))
		var/datum/movespeed_modifier/nommed_someone/nom = new
		nom.id = "[ref(arrived)]_nommed"
		belly_slowdown_refs += nom.id
		nom.multiplicative_slowdown = 1.5
		owner.add_movespeed_modifier(nom)
		var/mob/living/carbon/carbon_arrived = arrived
		carbon_arrived.update_suit_sensors()
	update_static_vore_data()

/datum/vore_belly/proc/proxy_exited(atom/movable/gone, direction)
	if (gone in absorbed)
		absorbed -= gone
		UnregisterSignal(gone, COMSIG_PARENT_EXAMINE)
	if (gone in absorbing)
		absorbing -= gone
	if (isliving(gone))
		UnregisterSignal(gone, COMSIG_LIVING_RESIST)
		var/mob/living/living_gone = gone
		living_gone.cure_blind(belly_string_ref)
		if (living_gone.client?.prefs?.vr_prefs)
			living_gone.client.prefs.vr_prefs.needs_update |= UPDATE_INSIDE
			living_gone.client.prefs.vr_prefs.update_static_data(living_gone)
	if (iscarbon(gone))
		owner.remove_movespeed_modifier("[ref(gone)]_nommed")
		belly_slowdown_refs -= "[ref(gone)]_nommed"
		var/mob/living/carbon/carbon_gone = gone
		carbon_gone.update_suit_sensors()
	check_mode()
	update_static_vore_data()

/datum/vore_belly/proc/update_static_vore_data(force=FALSE, only_contents=FALSE, timer = FALSE)
	static_data_cooldown = (force || timer) ? 0 : static_data_cooldown
	static_timer = timer ? FALSE : static_timer
	if (static_data_cooldown > world.time)
		if (!static_timer)
			static_timer = TRUE
			addtimer(CALLBACK(src, .proc/update_static_vore_data, FALSE, FALSE, TRUE), static_data_cooldown - world.time)
		return
	static_data_cooldown = world.time + 0.5 SECONDS
	for (var/mob/living/living in belly_obj)
		if (living.client?.prefs?.vr_prefs)
			living.client.prefs.vr_prefs.needs_update |= UPDATE_INSIDE
			living.client.prefs.vr_prefs.update_static_data(living)
	if (!only_contents && owner.client?.prefs?.vr_prefs)
		owner.client.prefs.vr_prefs.needs_update |= UPDATE_CONTENTS
		owner.client.prefs.vr_prefs.update_static_data(owner)

/datum/vore_belly/proc/get_belly_contents(ref=FALSE, living=FALSE, as_string=FALSE, ignored=null, full=FALSE)
	var/list/belly_contents = list()
	var/list/keep_track = list()
	for (var/atom/movable/AM as anything in belly_obj)
		if (ignored && (AM == ignored || (AM in ignored)))
			continue
		if (living && !isliving(AM))
			continue
		var/key = as_string ? "[AM][keep_track["[AM]"] ? " ([keep_track["[AM]"]])" : ""]" : AM
		if (full)
			belly_contents += list(list("name" = key, "absorbed" = (AM in absorbed), "ref" = ref(AM))) //double list because byond is dumb and this is the only way to add a list to a list afaik
		else if (ref)
			belly_contents[key] = ref(AM)
		else
			belly_contents += key
		keep_track["[AM]"] = keep_track["[AM]"] ? keep_track["[AM]"] + 1 : 2
	return belly_contents

/datum/vore_belly/proc/check_mode()
	if (mode == VORE_MODE_HOLD)
		return
	START_PROCESSING(SSobj, src) //new subsystem?

/datum/vore_belly/process()
	var/all_done = TRUE //should it stop processing
	var/should_update = FALSE //should it call a vore prefs ui update on mobs inside, and on the owner
	switch(mode)
		if (VORE_MODE_HOLD)
			all_done = TRUE
		if (VORE_MODE_DIGEST)
			for (var/mob/living/prey in belly_obj)
				if (!prey.check_vore_toggle(DIGESTABLE, VORE_MECHANICS_TOGGLES))
					continue
				prey.apply_damage(4, BURN)
				if (prey.stat == DEAD)
					var/pred_message = vore_replace(data[LIST_DIGEST_PRED], owner, prey, name)
					var/prey_message = vore_replace(data[LIST_DIGEST_PREY], owner, prey, name)
					vore_message(owner, pred_message, SEE_OTHER_MESSAGES, warning=TRUE)
					vore_message(prey, prey_message, SEE_OTHER_MESSAGES, warning=TRUE)
					prey.release_belly_contents()
					for (var/obj/item/item in prey)
						if (!prey.dropItemToGround(item))
							qdel(item)
					if (prey.check_vore_toggle(LEAVE_ESSENCE_CUBE, VORE_MECHANICS_TOGGLES))
						new /obj/item/essence_cube(belly_obj, prey)
					else
						qdel(prey)
					should_update = TRUE
				else
					all_done = FALSE

		//may wanna make this use nutrition in the future or something
		if (VORE_MODE_ABSORB)
			for (var/mob/living/prey in absorbed)
				if (!prey.check_vore_toggle(ABSORBABLE, VORE_MECHANICS_TOGGLES))
					absorbed -= prey
					should_update = TRUE
					continue
				if (absorbed[prey] < 100)
					absorbed[prey] += 2
					all_done = FALSE
			for (var/mob/living/prey in belly_obj)
				if ((prey in absorbed) || !prey.check_vore_toggle(ABSORBABLE, VORE_MECHANICS_TOGGLES))
					if (prey in absorbing)
						absorbing -= prey
					continue
				if (!absorbing[prey])
					absorbing[prey] = 0
				absorbing[prey] += 2 //fires every 2 seconds, so this will take 100 seconds
				if (absorbing[prey] >= 100)
					RegisterSignal(prey, COMSIG_PARENT_EXAMINE, .proc/examine_absorb)
					var/pred_message = vore_replace(data[LIST_ABSORB_PRED], owner, prey, name)
					var/prey_message = vore_replace(data[LIST_ABSORB_PREY], owner, prey, name)
					vore_message(owner, pred_message, SEE_OTHER_MESSAGES, warning=TRUE)
					vore_message(prey, prey_message, SEE_OTHER_MESSAGES, warning=TRUE)
					absorbing -= prey
					absorbed[prey] = 100
					should_update = TRUE
				else
					all_done = FALSE

		if (VORE_MODE_UNABSORB)
			for (var/mob/living/prey in absorbed)
				if (!(prey in belly_obj))
					absorbed -= prey
					should_update = TRUE
					continue
				absorbed[prey] -= 2 //fires every 2 seconds, so this will take 100 seconds
				if (absorbed[prey] <= 0)
					UnregisterSignal(prey, COMSIG_PARENT_EXAMINE)
					var/pred_message = vore_replace(data[LIST_UNABSORB_PRED], owner, prey, name)
					var/prey_message = vore_replace(data[LIST_UNABSORB_PREY], owner, prey, name)
					vore_message(owner, pred_message, SEE_OTHER_MESSAGES, warning=TRUE)
					vore_message(prey, prey_message, SEE_OTHER_MESSAGES, warning=TRUE)
					absorbed -= prey
					should_update = TRUE
				else
					all_done = FALSE
			for (var/mob/living/prey in absorbing)
				if (!(prey in belly_obj))
					absorbing -= prey
					should_update = TRUE
					continue
				absorbing[prey] -= 2
				if (absorbing[prey] <= 0)
					absorbing -= prey
				else
					all_done = FALSE

	if (all_done)
		STOP_PROCESSING(SSobj, src)
	if (should_update)
		update_static_vore_data()

/datum/vore_belly/proc/mass_release_from_contents(willing=FALSE)
	for (var/atom/movable/to_release as anything in belly_obj)
		if (willing && (to_release in absorbed))
			continue
		to_release.forceMove(belly_obj.drop_location())
	//add a message here?

/datum/vore_belly/proc/release_from_contents(atom/movable/to_release, willing=FALSE)
	if (!(to_release in belly_obj) || (willing && (to_release in absorbed)))
		return FALSE
	to_release.forceMove(belly_obj.drop_location())
	var/pred_message = "You eject [to_release] from your [name]!"
	var/audience_message = "[owner] ejects [to_release] from [owner.p_their()] [name]!"
	send_vore_message(owner, pred_message, null, audience_message, SEE_OTHER_MESSAGES)

/datum/vore_belly/proc/on_examine(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER

	if (!user.check_vore_toggle(SEE_EXAMINES))
		return
	if (!length(data[LIST_EXAMINE]))
		return
	for (var/mob/living/living_mob in belly_obj)
		examine_list += SPAN_WARNING(vore_replace(data[LIST_EXAMINE], owner, living_mob, name))
		break //not sure how you'd do this with multiple prey... hm.

/datum/vore_belly/proc/examine_absorb(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER

	if (!user.check_vore_toggle(SEE_EXAMINES))
		return
	for (var/mob/living/absorbee as anything in absorbed)
		if (!(absorbee in belly_obj))
			absorbed -= absorbee
			UnregisterSignal(absorbee, COMSIG_PARENT_EXAMINE)
			continue
		examine_list += "<span class='purple bold italic'>[absorbee] has been absorbed into [user == owner ? "your" : "[owner]'s"] [name]!</span>"

/datum/vore_belly/proc/prey_resist(datum/source, mob/living/prey) //incorporate struggling mechanics later?
	if (prey in absorbed) //should this stay? or do we want absorbed victims to be able to struggle
		return
	var/prey_message = vore_replace(data[LIST_STRUGGLE_INSIDE], owner, prey, name)
	var/list/ignored_mobs = list()
	for (var/mob/living/prey_target in belly_obj)
		ignored_mobs += prey_target
		vore_message(prey_target, prey_message, SEE_STRUGGLES, warning=TRUE)
	var/pred_and_audience_message = vore_replace(data[LIST_STRUGGLE_OUTSIDE], owner, prey, name)
	if (pred_and_audience_message)
		send_vore_message(owner, SPAN_WARNING(pred_and_audience_message), null, SPAN_WARNING(pred_and_audience_message), SEE_STRUGGLES, prey=prey, ignored=ignored_mobs)
