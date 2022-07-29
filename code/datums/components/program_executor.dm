// general purpose programming language?

/datum/component/programExecutor
	// compiled program
	var/datum/computer/file/custom_program/program

	// peripherals etc
	var/list/inputs
	var/list/outputs

	Initialize()
		src.inputs = list()
		src.outputs = list()

		..()

	RegisterWithParent()
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_EXECUTE), .proc/execute)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_HALT), .proc/halt)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_IN), .proc/signalIn)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_OUT), .proc/signalOut)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_ADD_IN), .proc/newIn)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_REMOVE_IN), .proc/removeIn)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_ADD_OUT), .proc/newOut)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_REMOVE_OUT), .proc/removeOut)
		return

	UnregisterFromParent()
		var/list/signals = list(\
		COMSIG_PROGRAM_EXECUTE\
		COMSIG_PROGRAM_HALT,\
		COMSIG_PROGRAM_IN,\
		COMSIG_PROGRAM_OUT,\
		COMSIG_PROGRAM_ADD_IN,\
		COMSIG_PROGRAM_REMOVE_IN,\
		COMSIG_PROGRAM_ADD_OUT,\
		COMSIG_PROGRAM_REMOVE_OUT)
		src.UnregisterSignal(parent, signals)
		src.inputs.Cut()
		src.outputs.Cut()
		return
