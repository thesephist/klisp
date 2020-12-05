all: ci

# run main binary
run:
	ink ./src/cli.ink test/000.klisp
	ink ./src/cli.ink test/001.klisp
	ink ./src/cli.ink test/002.klisp
	ink ./src/cli.ink test/003.klisp
	ink ./src/cli.ink test/004.klisp
	ink ./src/cli.ink test/005.klisp
	ink ./src/cli.ink test/006.klisp

# run as repl
repl:
	rlwrap ink ./src/cli.ink

# run nightvale server on an auto-restart loop
serve:
	until ink ./src/cli.ink --port 7900; do echo 'Re-starting Nightvale...'; done

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

# run by CI, uses vendored Ink binary
ci:
	./util/ink-linux ./src/cli.ink test/000.klisp
	./util/ink-linux ./src/cli.ink test/001.klisp
	./util/ink-linux ./src/cli.ink test/002.klisp
	./util/ink-linux ./src/cli.ink test/003.klisp
	./util/ink-linux ./src/cli.ink test/004.klisp
	./util/ink-linux ./src/tests.ink

