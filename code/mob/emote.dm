// the old emote.dm scares me
/mob/living/emote_check(var/voluntary = 1, var/time = 10, var/admin_bypass = 1, var/dead_check = 1)
	if (!src.emote_allowed)
		return 0

	if (dead_check && isdead(src))
		src.emote_allowed = 0
		return 0

	if (voluntary && (src.getStatusDuration("paralysis") > 0 || isunconscious(src)))
		return 0

	if (no_emote_cooldowns || admin_bypass || !voluntary || !ON_COOLDOWN(src, "emote", time))

	else
		return 0

// emotes
/datum/emote
	var/list/aliases = list()

	do_emote(var/mob/M, var/voluntary = 0, var/param = null)
		return

/datum/emote/scream
	aliases = list(
		"scream"
	)

	do_emote(var/mob/M, var/voluntary = 0, var/param = null)
		return
