/datum/telnet_connection
	var/client/holder // client we are attached to

	New(client)
		if (!client)
			return

		src.holder = client
		return ..()
