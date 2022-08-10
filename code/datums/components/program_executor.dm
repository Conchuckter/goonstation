#define ERROR_SUCCESSFUL 0 // no error
#define ERROR_UNDEFINED -1
#define INSTRUCTION_ERROR_MESSAGE "ERROR: No return variable. MORE_INFO:\n"

// ---- Executor ----
/datum/component/program_executor
	// compiled program
	var/datum/computer/file/compiled_program/program

	// peripherals etc
	var/list/outputs

	var/list/global_variables
	var/halt_now = 0 // we need to halt!
	var/executing = 0 // whether we are executing or not

	Initialize()
		src.outputs = list()
		src.global_variables = list()

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

	proc/execute(var/comsig_target, var/datum/computer/file/compiled_program/program = null, var/list/arguments)
		if (istype(program))
			src.program = program

		if (src.executing || !program)
			return

		src.terminal_message("Execution Started...")
		src.executing = 1
		src.call_function("init", arguments)

	proc/halt(var/comsig_target, var/reason = null)
		src.halt_now = 1
		if (reason)
			src.terminal_message("Execution Halting... Reason: [reason]")
			return

		src.terminal_message("Execution Halting...")

	proc/halted()
		src.halt_now = 0
		src.executing = 0
		src.global_variables.Cut()
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

	proc/terminal_error(var/text)
		return

	proc/terminal_message(var/text)
		return

	proc/handle_errors(var/error)
		return

	proc/call_function(var/function_name, var/list/arguments, var/return_variable= null)
		var/list/local_variables = list()

		var/datum/program_function/function = src.program.functions[function_name]
		for (var/datum/program_instruction/PI in function.instructions)
			if (src.halt_now)
				src.halted()
				return

			var/list/instruction_arguments = replace_arguments(PI.arguments, local_variables, src.global_variables)
			switch (lowertext(PI.keyword))
				if ("var")
					if (!PI.return_variable)
						return INSTRUCTION_ERROR_MESSAGE + PI.error_message

					if (length(PI.arguments))
						local_variables[PI.return_variable] = instruction_arguments[1]
					else
						local_variables[PI.return_variable] = null

				if ("glo")
					if (!PI.return_variable)
						return INSTRUCTION_ERROR_MESSAGE + PI.error_message

					if (!(PI.return_variable in local_variables))
						return ERROR_UNDEFINED + PI.error_message

					if (!(PI.return_variable in src.global_variables))
						src.global_variables.Add(PI.return_variable)

					src.global_variables[PI.return_variable] = local_variables[PI.return_variable]

				if ("out")
					if (!instruction_arguments[0] || !instruction_arguments[1])
						return

					var/result = SEND_SIGNAL(src, COMSIG_PROGRAM_OUT, address, signal_out)
					if (!PI.return_variable || !result)
						return

					if (!(PI.return_variable in local_variables))
						return ERROR_UNDEFINED

					local_variables[PI.return_variable] = result



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

			var/variable_name = copytext(argument, variable_left + 1, variable_right)
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

TYPEINFO(/datum/component/program_executor)
	initialization_args = null

// ---- Program ----
/datum/program_signal
	var/signal
	var/datum/computer/file/file

/datum/program_function
	var/list/instructions = list()

/datum/program_function/test
	New()
		..()
		var/datum/program_instruction/instruction = new/datum/program_instruction
		instruction.keyword = "var"
		instruction.return_variable = "test"
		instruction.arguments.Add(2)
		src.instructions.Add(instruction)
		instruction = new/datum/program_instruction
		instruction.keyword = "var"
		instruction.return_variable = "test2"
		instruction.arguments.Add("4$test$4")
		src.instructions.Add(instruction)
		instruction = new/datum/program_instruction
		instruction.keyword = "glo"
		instruction.return_variable = "test2"
		src.instructions.Add(instruction)

/datum/program_instruction
	var/keyword = null
	var/error_message = "ERROR"
	var/return_variable = null
	var/list/arguments = list()

/datum/computer/file/compiled_program
	name = "Program"
	extension = "CPROG"
	size = 2

	var/list/functions = list()

	disposing()
		src.functions.Cut()
		..()

/datum/computer/file/compiled_program/test
	name = "Test Program"

	New()
		..()
		var/function = new/datum/program_function/test
		src.functions.Add("init")
		src.functions["init"] = function

/obj/test
	name = "test"
	icon = 'icons/obj/networked.dmi'
	icon_state = "serverf"

	New()
		..()
		AddComponent(/datum/component/program_executor)
		var/program = new/datum/computer/file/compiled_program/test
		SEND_SIGNAL(src, COMSIG_PROGRAM_EXECUTE, program)


#undef ERROR_SUCCESSFUL
#undef ERROR_UNDEFINED
