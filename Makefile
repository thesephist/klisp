all: run

# run main binary
run:
	ink ./src/cli.ink test/000.klisp
	ink ./src/cli.ink test/001.klisp
	ink ./src/cli.ink test/002.klisp

# run as repl
repl:
	rlwrap ink ./src/cli.ink

# run all tests under test/
check: run
	ink ./src/tests.ink
t: check

fmt:
	inkfmt fix src/*.ink
f: fmt

fmt-check:
	inkfmt src/*.ink
fk: fmt-check

configure:
	cp util/klisp.vim ~/.vim/syntax/klisp.vim

install:
	sudo echo '#!/bin/sh' > /usr/local/bin/klisp
	sudo echo rlwrap `pwd`/src/cli.ink '$$*' >> /usr/local/bin/klisp
	sudo chmod +x /usr/local/bin/klisp

