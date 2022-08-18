// Variables
#define INSTRUCTION_VAR 0
#define INSTRUCTION_GLOBAL 1
// Peripherals
#define INSTRUCTION_OUT 2
// Arithmatic
#define INSTRUCTION_ADD 3
#define INSTRUCTION_SUB 4
#define INSTRUCTION_MUL 5
#define INSTRUCTION_DIV 6
#define INSTRUCTION_MOD 7
// Logical
#define INSTRUCTION_EQ 8
#define INSTRUCTION_LT 9
#define INSTRUCTION_GT 10
#define INSTRUCTION_LTEQ 11
#define INSTRUCTION_GTEQ 12
#define INSTRUCTION_NOT 13
#define INSTRUCTION_OR 14
#define INSTRUCTION_AND 15
// Control
#define INSTRUCTION_JMP 16
#define INSTRUCTION_RETURN 17

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

	proc/signal_out(var/address, var/signal)
		var/datum/program_signal/S = new/datum/program_signal
		S.signal = signal
		if (!(address in src.outputs))
			src.terminal_error("Unknown Output: [address]")
			return 1

		call(src.parent, src.outputs[address])(S)

	proc/signal_in(var/comsig_target, var/sender, var/signal)
		src.call_function("input", list(sender, signal))

	proc/terminal_error(var/text)
		return

	proc/terminal_message(var/text)
		return

	proc/call_function(var/function_name, var/list/arguments, var/return_variable= null)
		var/list/local_variables = list()
		local_variables.Add("argc")
		local_variables["argc"] = length(arguments)
		for (var/i = 1, !(i > length(arguments)), i++)
			local_variables["arg[i-1]"] = arguments[i]

		var/datum/program_function/function = src.program.functions[function_name]
		var/function_length = length(function.instructions)
		for (var/i = 1, !(i > function_length), i++)
			var/datum/program_instruction/PI = function.instructions[i]
			if (!istype(PI))
				return

			if (src.halt_now)
				src.halted()
				return

			var/list/instruction_arguments = replace_arguments(PI.arguments, local_variables, src.global_variables)
			var/argument_length = length(instruction_arguments)
			switch (lowertext(PI.code))
				if (INSTRUCTION_VAR)
					if (!PI.return_variable)
						src.terminal_error("[i]: Missing Return Variable")
						return

					if (argument_length)
						local_variables[PI.return_variable] = instruction_arguments[1]
					else
						local_variables[PI.return_variable] = null

				if (INSTRUCTION_GLOBAL)
					if (!PI.return_variable)
						src.terminal_error("[i]: Missing Return Variable")
						return

					if (!(PI.return_variable in local_variables))
						src.terminal_error("[i]: Undefined Return Variable")
						return

					if (!(PI.return_variable in src.global_variables))
						src.global_variables.Add(PI.return_variable)

					src.global_variables[PI.return_variable] = local_variables[PI.return_variable]

				if (INSTRUCTION_OUT)
					if (argument_length < 2)
						src.terminal_error("[i]: Insufficient Arguments")
						return

					var/result = src.signal_out(instruction_arguments[1], instruction_arguments[2])
					if (!PI.return_variable || !result)
						continue

					if (!(PI.return_variable in local_variables))
						src.terminal_error("[i]: Undefined Return Variable")
						return

					local_variables[PI.return_variable] = result

				if (INSTRUCTION_ADD)
					if (argument_length < 2)
						src.terminal_error("[i]: Insufficient Arguments")
						return

					if (!PI.return_variable)
						src.terminal_error("[i]: No Return Variable")
						return

					if (!(PI.return_variable in local_variables))
						src.terminal_error("[i]: Undefined Return Variable")
						return

					var/result
					for (var/argument in instruction_arguments)
						result += text2num_safe(argument)

					local_variables[PI.return_variable] = result

				if (INSTRUCTION_SUB)
					if (argument_length < 2)
						src.terminal_error("[i]: Insufficient Arguments")
						return

					if (!PI.return_variable)
						src.terminal_error("[i]: No Return Variable")
						return

					if (!(PI.return_variable in local_variables))
						src.terminal_error("[i]: Undefined Return Variable")
						return

					var/result
					for (var/argument in instruction_arguments)
						result -= text2num_safe(argument)

					local_variables[PI.return_variable] = result

				if (INSTRUCTION_MUL)
					if (argument_length < 2)
						src.terminal_error("[i]: Insufficient Arguments")
						return

					if (!PI.return_variable)
						src.terminal_error("[i]: No Return Variable")
						return

					if (!(PI.return_variable in local_variables))
						src.terminal_error("[i]: Undefined Return Variable")
						return

					var/result
					for (var/argument in instruction_arguments)
						result *= text2num_safe(argument)

					local_variables[PI.return_variable] = result

				if (INSTRUCTION_DIV)
					if (argument_length < 2)
						src.terminal_error("[i]: Insufficient Arguments")
						return

					if (!PI.return_variable)
						src.terminal_error("[i]: No Return Variable")
						return

					if (!(PI.return_variable in local_variables))
						src.terminal_error("[i]: Undefined Return Variable")
						return

					var/result
					for (var/argument in instruction_arguments)
						result /= text2num_safe(argument)

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
				return

			var/variable_name = copytext(argument, variable_left + 1, variable_right)
			if (!variable_name)
				return

			if (variable_name in local_variables)
				replaced_arguments.Add(local_variables[variable_name])
				continue
			else if (variable_name in global_variables)
				replaced_arguments.Add(global_variables[variable_name])
				continue
			else
				return

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
		instruction.code = INSTRUCTION_VAR
		instruction.return_variable = "test"
		src.instructions.Add(instruction)
		instruction = new/datum/program_instruction
		instruction.code = INSTRUCTION_ADD
		instruction.return_variable = "test"
		instruction.arguments.Add("$arg1$", 5)
		src.instructions.Add(instruction)
		instruction = new/datum/program_instruction
		instruction.code = INSTRUCTION_OUT
		instruction.arguments.Add("testout", "$test$")
		src.instructions.Add(instruction)

/datum/program_instruction
	var/code = null
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
		src.functions.Add("input")
		src.functions["input"] = function

/obj/test
	name = "test"
	icon = 'icons/obj/networked.dmi'
	icon_state = "serverf"

	New()
		..()
		AddComponent(/datum/component/program_executor)
		var/program = new/datum/computer/file/compiled_program/test
		SEND_SIGNAL(src, COMSIG_PROGRAM_ADD_OUT, "testout", .proc/testout)
		SEND_SIGNAL(src, COMSIG_PROGRAM_EXECUTE, program)

	hear_talk(mob/M, text, real_name)
		SEND_SIGNAL(src, COMSIG_PROGRAM_IN, "chat", text[1])
		..()

	proc/testout(var/datum/program_signal/signal)
		if (isnum(signal.signal))
			src.visible_message(num2text(signal.signal))
			return

		src.visible_message(signal.signal)
