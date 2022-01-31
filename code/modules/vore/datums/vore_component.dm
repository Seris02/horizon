/datum/component/vore
	var/list/obj/vbelly/bellies = list()
	var/mob/living/owner
	var/char_vars
	var/vore_toggles = list()
	var/selected_belly = 1
	var/vore_enabled = TRUE
	var/current_slot

/datum/component/vore/Initialize()
	if (!isliving(parent))
		return COMPONENT_INCOMPATIBLE
	owner = parent
	if (ishuman(owner))
		var/mob/living/carbon/human/character = owner
		current_slot = character.character_slot
	RegisterSignal(owner, COMSIG_PARENT_PREQDELETED, .proc/handle_delete)
	update_bellies(TRUE)

/datum/component/vore/Destroy()
	UnregisterSignal(owner, COMSIG_PARENT_PREQDELETED)
	handle_delete()
	. = ..()

/datum/component/vore/proc/update_current_slot()
	if (!isnull(current_slot))
		return current_slot
	if (ishuman(owner))
		var/mob/living/carbon/human/character = owner
		current_slot = character.character_slot
		if (!isnull(current_slot))
			return current_slot
	current_slot = owner.client?.prefs.default_slot
	return current_slot

/datum/component/vore/proc/handle_delete()
	SIGNAL_HANDLER

	owner.release_belly_contents()

/datum/component/vore/proc/get_belly_contents(bellynum, ref=FALSE, living=FALSE, as_string=FALSE, ignored=null, full=FALSE)
	if (bellynum < 1 || bellynum > bellies.len)
		return
	var/list/belly_contents = bellies[bellynum].get_belly_contents(ref, living, as_string, ignored, full)
	return belly_contents

/datum/component/vore/proc/update_bellies(set_ref=FALSE) //update everything
	if (!owner.client?.prefs?.vr_prefs)
		return
	var/datum/vore_prefs/vore = owner.client.prefs.vr_prefs
	vore_toggles = vore.vore_toggles
	char_vars = vore.char_vars
	selected_belly = vore.selected_belly
	vore_enabled = vore.vore_enabled
	for (var/bellynum in 1 to vore.bellies.len)
		var/belly_ref = (set_ref ? bellynum : null)
		if (bellynum > bellies.len)
			var/obj/vbelly/belly = new(null, owner, vore.bellies[bellynum], belly_ref)
			bellies += belly
		else
			var/obj/vbelly/belly = bellies[bellynum]
			belly.set_data(vore.bellies[bellynum], belly_ref)

/datum/component/vore/proc/update_belly(bellynum, data)
	if (!bellynum || bellynum > bellies.len)
		return
	bellies[bellynum].set_data(data)

/datum/component/vore/proc/remove_belly(bellynum)
	if (!bellynum || bellynum > bellies.len)
		return
	var/obj/vbelly/belly = bellies[bellynum]
	belly.mass_release_from_contents()
	bellies.Cut(bellynum, bellynum+1)
	qdel(belly)

//change this to mob/living once/if you make simplemob vore a thing
/mob/living/carbon/human/Login()
	. = ..()
	if (!. || !client)
		return
	update_vore_verbs()

/mob/living/proc/update_vore_verbs()
	if (client.prefs?.vr_prefs?.vore_enabled)
		var/datum/component/vore/vore = LoadComponent(/datum/component/vore)
		client.prefs.vr_prefs.load_slotted_prefs()
		vore.update_bellies()
		hud_used?.nom_button?.update_visibility()

/mob/living/verb/OOC_Escape()
	set name = "OOC Escape"
	set category = "OOC"

	while(istype(loc, /obj/vbelly))
		var/obj/vbelly/belly = loc
		forceMove(belly.drop_location())

/mob/living/proc/Ingest(mob/living/prey, mob/living/inside_of = null, obj/vbelly/belly_inside = null)
	//I wonder if I should put a fun little animation here... probably not
	if (prey == src)
		return
	if (!prey.check_vore_toggle(DEVOURABLE, VORE_MECHANICS_TOGGLES))
		to_chat(src, SPAN_WARNING("[prey] can't be eaten!"))
		return
	var/datum/component/vore/vore = LoadComponent(/datum/component/vore)
	var/belly_name = vore.bellies[vore.selected_belly].name
	var/belly_swallow = vore.bellies[vore.selected_belly].swallow_verb
	var/pred_message = SPAN_WARNING("You begin to [belly_swallow] [prey] into your [belly_name]!")
	var/prey_message = SPAN_WARNING("[src] begins to [belly_swallow] you into [p_their()] [belly_name]!")
	var/audience_message = SPAN_WARNING("[src] is attempting to [belly_swallow] [prey] into [p_their()] [belly_name]!")
	if (inside_of)
		vore_message(inside_of, "Someone inside of you is eating someone else!", SEE_OTHER_MESSAGES, warning=TRUE)
	send_vore_message(src, pred_message, prey_message, audience_message, SEE_OTHER_MESSAGES, prey=prey, only=(inside_of ? belly_inside.get_belly_contents(living=TRUE) : null))
	if (!do_after(src, VORE_EATING_TIME, prey))
		return
	var/obj/vbelly/belly = vore?.bellies[vore.selected_belly]
	if (belly)
		var/pred_message2 = SPAN_WARNING("You manage to [belly_swallow] [prey] into your [belly_name]!")
		var/prey_message2 = SPAN_WARNING("[src] manages to [belly_swallow] you into [p_their()] [belly_name]!")
		var/audience_message2 = SPAN_WARNING("[src] manages to [belly_swallow] [prey] into [p_their()] [belly_name]!")
		if (inside_of)
			vore_message(inside_of, "Someone inside of you has eaten someone else!", SEE_OTHER_MESSAGES, VORE_CHAT_TOGGLES, warning=TRUE)
		send_vore_message(src, pred_message2, prey_message2, audience_message2, SEE_OTHER_MESSAGES, prey=prey, only=(inside_of ? belly_inside.get_belly_contents(living=TRUE) : null))
		prey.forceMove(belly)
