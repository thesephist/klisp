all: run

# run main binary
run:
	ink ./src/klisp.ink

# run all tests under test/
check:
	ink ./src/main.ink test/*.ink
t: check

fmt:
	inkfmt fix src/*.ink
f: fmt

fmt-check:
	inkfmt src/*.ink
fk: fmt-check
