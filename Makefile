all: run

# run main binary
run:
	ink ./src/cli.ink test/000.klisp

# run as repl
repl:
	rlwrap ink ./src/cli.ink

# run all tests under test/
check:
	ink ./src/tests.ink
	ink ./src/cli.ink test/*.klisp
t: check

fmt:
	inkfmt fix src/*.ink
f: fmt

fmt-check:
	inkfmt src/*.ink
fk: fmt-check
