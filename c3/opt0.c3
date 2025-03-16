module brainz::opt0;
import std::io;

fn void? interpret(
	Program program,
	char[] memory,
	InStream rdr = io::stdin(),
	OutStream wtr = io::stdout(),
) {
	char[] instructions = program;
	uint pc;
	uint dataptr;

	while (pc < instructions.len) {
		char instruction = instructions[pc];

		switch (instruction) {
			case '>': dataptr += 1;
			case '<': dataptr -= 1;
			case '+': memory[dataptr] += 1;
			case '-': memory[dataptr] -= 1;
			case ',': memory[dataptr] = rdr.read_byte()!;
			case '.': wtr.write_byte(memory[dataptr])!;
			case '[':
				// jumps to next matching ']' if curr_data == 0
				if (memory[dataptr] != 0) {
					break;
				}

				uint bracket_nesting = 1;
				uint saved_pc = pc; // used for error message only

				while (bracket_nesting != 0 && pc < instructions.len - 1) {
					pc += 1;

					if (instructions[pc] == ']') {
						bracket_nesting -= 1;
					} else if (instructions[pc] == '[') {
						bracket_nesting += 1;
					}
				}

				if (bracket_nesting != 0) {
					io::eprintfn("unmatched '[' at pc=%d", saved_pc);
					return UNMATCHED_LBRACKET?;
				}
			case ']':
				// jumps to previous matching ']' if curr data != 0
				if (memory[dataptr] == 0) {
					break;
				}

				uint bracket_nesting = 1;
				uint saved_pc = pc; // used for error message only

				while (bracket_nesting != 0 && pc > 0) {
					pc -= 1;

					if (instructions[pc] == '[') {
						bracket_nesting -= 1;
					} else if (instructions[pc] == ']') {
						bracket_nesting += 1;
					}
				}

				if (bracket_nesting != 0) {
					io::eprintfn("unmatched ']' at pc=%d", saved_pc);
					return UNMATCHED_RBRACKET?;
				}
			default:
				return UNREACHABLE_CHAR?;
		}
		pc += 1;
	}
}

faultdef
	UNMATCHED_LBRACKET,
	UNMATCHED_RBRACKET,
	UNREACHABLE_CHAR,
;
