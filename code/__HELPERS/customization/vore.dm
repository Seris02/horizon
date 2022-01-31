/proc/vore_replace(messages, mob/living/pred=null, mob/living/prey=null, belly=null)
	if (!istext(messages) && !(islist(messages) && length(messages)))
		return ""
	var/message = istext(messages) ? messages : pick(messages)
	var/list/replacements = list("%pred" = "[pred]", "%prey" = "[prey]", "%belly" = "[belly]")
	for (var/replacement in replacements)
		message = replacetext(message, replacement, replacements[replacement])
	return message

/proc/send_vore_message(atom/movable/pred, pred_message, prey_message, audience_message, pref_respecting, section=VORE_CHAT_TOGGLES, prey=null, replace=TRUE, ignored=null, audience=TRUE, only=null)
	var/turf/T = get_turf(pred)
	if (!pred || !pred_message || (!T && !only && audience))
		return
	var/list/hearers = only ? only : (audience ? get_hearers_in_view(DEFAULT_MESSAGE_RANGE, pred) : list(pred, prey))
	for (var/mob/hearer in hearers)
		if (!hearer || !hearer.check_vore_toggle(pref_respecting, section))
			continue
		if (ignored && (hearer in ignored))
			continue
		if (!only && audience && hearer.lighting_alpha > LIGHTING_PLANE_ALPHA_MOSTLY_INVISIBLE && T.is_softly_lit() && !in_range(T,hearer))
			continue
		if (hearer == pred)
			to_chat(hearer, pred_message)
		else if (prey && hearer == prey)
			to_chat(hearer, prey_message)
		else
			to_chat(hearer, audience_message)

/proc/vore_message(mob/target, message, pref_respecting, section=VORE_CHAT_TOGGLES, warning=FALSE)
	if (!istype(target) || !message)
		return
	if (!isnull(pref_respecting) && !target.check_vore_toggle(pref_respecting, section))
		return
	if (warning)
		message = SPAN_WARNING(message)
	to_chat(target, message)

/* make sure to implement a sound cooldown before you use this
/proc/send_vore_sound(atom/movable/source, sound, pref_respecting, range=DEFAULT_MESSAGE_RANGE)
	if (!source || !sound)
		return
	for (var/mob/hearer in get_hearers_in_view(range, source))
		if (!hearer.check_vore_toggle(pref_respecting))
			continue
		if(HAS_TRAIT(hearer, TRAIT_DEAF))
			continue
		SEND_SOUND(hearer, sound)
*/

/mob/proc/check_vore_enabled()
	var/datum/component/vore/vore = GetComponent(/datum/component/vore)
	return vore?.vore_enabled || client?.prefs?.vr_prefs.vore_enabled

/mob/proc/check_vore_toggle(toggle, section=VORE_CHAT_TOGGLES)
	return client?.prefs?.vr_prefs.vore_enabled && (client.prefs.vr_prefs.vore_toggles[section] & toggle)

/mob/living/check_vore_toggle(toggle, section=VORE_CHAT_TOGGLES)
	. = ..()
	if (.)
		return
	var/datum/component/vore/vore = GetComponent(/datum/component/vore)
	return vore?.vore_enabled && (vore.vore_toggles[section] & toggle)

/mob/living/proc/release_belly_contents()
	var/datum/component/vore/vore = GetComponent(/datum/component/vore)
	for (var/obj/vbelly/belly as anything in vore?.bellies)
		belly.mass_release_from_contents()

/proc/default_belly_info()
	return list(BELLY_NAME = "belly", \
				BELLY_DESC = "", \
				BELLY_SWALLOW_VERB = "swallow",\
				BELLY_CAN_TASTE = "Yes",\
				BELLY_MODE = VORE_MODE_HOLD,\
				LIST_DIGEST_PREY = list(),\
				LIST_DIGEST_PRED = list(),\
				LIST_ABSORB_PREY = list(),\
				LIST_ABSORB_PRED = list(),\
				LIST_UNABSORB_PREY = list(),\
				LIST_UNABSORB_PRED = list(),\
				LIST_STRUGGLE_INSIDE = list(),\
				LIST_STRUGGLE_OUTSIDE = list(),\
				LIST_EXAMINE = list())

/proc/static_belly_vars() //this could probably be better
	var/static/list/belly_vars = list(	BELLY_NAME, \
										BELLY_DESC, \
										BELLY_SWALLOW_VERB,\
										BELLY_CAN_TASTE,\
										BELLY_MODE,\
										LIST_DIGEST_PREY,\
										LIST_DIGEST_PRED,\
										LIST_ABSORB_PREY,\
										LIST_ABSORB_PRED,\
										LIST_UNABSORB_PREY,\
										LIST_UNABSORB_PRED,\
										LIST_STRUGGLE_INSIDE,\
										LIST_STRUGGLE_OUTSIDE,\
										LIST_EXAMINE)
	return belly_vars
