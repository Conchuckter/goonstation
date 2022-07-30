/datum/programSignal
	var/signal
	var/datum/computer/file/file

// general purpose programming language?
/datum/component/programExecutor
	// compiled program
	var/datum/computer/file/compiled_program/program

	// peripherals etc
	var/list/inputs
	var/list/outputs

	var/executing

	Initialize()
		src.inputs = list()
		src.outputs = list()

		..()

	RegisterWithParent()
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_EXECUTE), .proc/execute)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_HALT), .proc/halt)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_IN), .proc/signalIn)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_OUT), .proc/signalOut)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_ADD_OUT), .proc/addOutput)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_REMOVE_OUT), .proc/removeOutput)
		return

	UnregisterFromParent()
		var/list/signals = list(\
		COMSIG_PROGRAM_EXECUTE\
		COMSIG_PROGRAM_HALT,\
		COMSIG_PROGRAM_IN,\
		COMSIG_PROGRAM_OUT,\
		COMSIG_PROGRAM_ADD_OUT,\
		COMSIG_PROGRAM_REMOVE_OUT)
		src.UnregisterSignal(parent, signals)
		src.inputs.Cut()
		src.outputs.Cut()
		return

	proc/execute()
		return

	proc/halt()
		return

	proc/addOutput(var/comsig_target, var/name, var/toCall)
		if (name in src.outputs)
			src.outputs.Remove(name)

		src.outputs.Add(name)
		src.outputs[name] = toCall

	proc/removeOutput(var/comsig_target, var/name)
		if (!name in src.outputs)
			return

		src.outputs.Remove(name)







