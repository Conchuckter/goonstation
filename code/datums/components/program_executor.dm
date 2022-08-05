#define ERROR_SUCCESSFUL 0 // no error
#define ERROR_UNDEFINED -1
#define INSTRUCTION_ERROR_MESSAGE "ERROR: No return variable. MORE_INFO:\n"

TYPEINFO(/datum/component/program_executor)
	initialization_args = null

// ---- Executor ----
/datum/component/program_executor
	// compiled program
	var/datum/computer/file/compiled_program/program

	// variables that are passed between functions
	var/datum/program_memory/memory

	// peripherals etc
	var/list/outputs

	var/halt = 0 // we need to halt!
	var/executing = 0 // whether we are executing or not

	Initialize()
		src.outputs = list()
		src.memory = new/datum/program_memory

		..()

	RegisterWithParent()
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_EXECUTE), .proc/execute)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_HALT), .proc/halt)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_IN), .proc/signal_in)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_OUT), .proc/signal_out)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_ADD_OUT), .proc/add_output)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_REMOVE_OUT), .proc/remove_output)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_TERMINAL_MESSAGE), .proc/terminal_message)
		src.RegisterSignal(src.parent, list(COMSIG_PROGRAM_TERMINAL_ERROR), .proc/terminal_error)
		return

	UnregisterFromParent()
		var/list/signals = list(\
		COMSIG_PROGRAM_EXECUTE,\
		COMSIG_PROGRAM_HALT,\
		COMSIG_PROGRAM_IN,\
		COMSIG_PROGRAM_OUT,\
		COMSIG_PROGRAM_ADD_OUT,\
		COMSIG_PROGRAM_REMOVE_OUT,\
		COMSIG_PROGRAM_TERMINAL_MESSAGE,\
		COMSIG_PROGRAM_TERMINAL_ERROR)
		src.UnregisterSignal(parent, signals)
		src.outputs.Cut()
		return

	proc/execute(var/comsig_target, var/list/arguments)
		if (src.executing)
			return

		src.terminal_message("Execution Started...")
		src.executing = 1
		src.call_function("init", arguments)

	proc/halt(var/comsig_target, var/reason = null)
		src.halt = 1
		if (reason)
			src.terminal_message("Execution Halting... Reason: [reason]")
			return

		src.terminal_message("Execution Halting...")

	proc/halted()
		src.halt = 0
		src.executing = 0
		src.terminal_message("Execution Stopped")
		SEND_SIGNAL(src.parent, COMSIG_PROGRAM_HALT) // parent can register this if they care

	proc/add_output(var/comsig_target, var/name, var/to_call)
		if (!(name in src.outputs))
			src.outputs.Remove(name)

		src.outputs.Add(name)
		src.outputs[name] = to_call

	// if peripherals get removed?
	proc/remove_output(var/comsig_target, var/name)
		if (!(name in src.outputs))
			return

		src.outputs.Remove(name)

	proc/signal_out(var/comsig_target, var/address, var/datum/program_signal)
		if (!(address in src.outputs))
			src.terminal_error("Unknown Output: [address]")
			return 1

		call(src.parent, src.outputs[address])(program_signal)

	proc/signal_in(var/comsig_target, var/sender, var/datum/program_signal/program_signal)
		src.call_function("in", list(sender, program_signal.signal, program_signal.file))

	proc/call_function(var/function, var/arguments)
		return // whatever the program function returns

	proc/terminal_error(var/text)
		return

	proc/terminal_message(var/text)
		return

	proc/handle_errors(var/error)
		return

/datum/program_memory
	var/list/variables

// ---- Program ----
/datum/program_signal
	var/signal
	var/datum/computer/file/file

/datum/program_function
	var/list/instructions

	proc/execute(var/return_variable, var/datum/program_memory/memory, var/list/arguments)
		var/list/local_variables


		for (var/datum/program_instruction/PI in src.instructions)
			var/instruction_arguments = replace_arguments(PI.arguments, local_variables, memory.variables)
			switch (lowertext(PI.keyword))
				if ("var")
					if (!PI.return_variable)
						return INSTRUCTION_ERROR_MESSAGE + PI.error_message

					local_variables.Add(PI.return_variable)

					if (!length(PI.arguments))
						return

					local_variables[PI.return_variable] = instruction_arguments[0]

				if ("call")
					if (PI.return_variable)



	proc/replace_arguments(var/list/arguments, var/list/local_variables, var/list/global_variables)
		var/list/replaced_arguments = list()

		for (var/argument in arguments)
			var/variable_left = findtext(argument, "$")
			if (!variable_left)
				replaced_arguments.Add(argument)
				continue

			var/variable_right = findtext(argument, "$", variable_left + 1)
			if (!variable_right)
				return ERROR_UNDEFINED

			var/regex/regex = regex(".*")
			var/variable_name = findtext(argument, regex, variable_left + 1, variable_right - 1)
			if (!variable_name)
				return ERROR_UNDEFINED

			if (variable_name in local_variables)
				replaced_arguments.Add(local_variables[variable_name])
				continue
			else if (variable_name in global_variables)
				replaced_arguments.Add(global_variables[variable_name])
				continue
			else
				return ERROR_UNDEFINED

		return replaced_arguments

/datum/program_instruction
	var/keyword = null
	var/error_message = "ERROR"
	var/return_variable = null
	var/list/arguments = list()

#undef ERROR_SUCCESSFUL
#undef ERROR_UNDEFINED
