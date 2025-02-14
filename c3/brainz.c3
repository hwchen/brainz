module brainz;
import std::collections;
import std::io;

const int MEMORY_SIZE = 30000;

fn int main(String[] args) {
	if (args.len < 2) {
		io::eprintn("Please provide source path");
	}
	String source_path = args[1];
	char[]! src = file::load_new(source_path);
	if (catch err = src) {
		io::eprintfn("Error reading source file");
		return 1;
	}

	Program! program = parse(src);
	if (catch err = program) {
		io::eprintfn("Error parsing program: %s", err);
		return 1;
	}

	char[] memory = mem::new_array(char, 30000);
	char opt_level = 0;
	switch (opt_level) {
		default:
			if (catch err = opt0::interpret(program, memory)) {
				io::eprintfn("Error running program: %s", err);
				return 1;
			}
	}
	return 0;
}

def Program = char[];

fn Program! parse(char[] src, Allocator alloc = allocator::heap()) {
	@pool(alloc) {
		List(<char>) instructions;
		instructions.temp_init();

		foreach (c : src) {
			switch (c) {
				case '>':
				case '<':
				case '+':
				case '-':
				case '.':
				case ',':
				case '[':
				case ']':
					instructions.push(c);
				default: {};
			}
		}
		return instructions.to_new_array(alloc);
	};
}
