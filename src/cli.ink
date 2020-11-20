` Klisp CLI `

std := load('../vendor/std')

log := std.log
f := std.format
scan := std.scan
slice := std.slice
readFile := std.readFile

klisp := load('klisp')

read := klisp.read
eval := klisp.eval
print := klisp.print
Env := klisp.Env

Version := '0.1'

paths := slice(args(), 2, len(args()))

path := paths.0 :: {
	() -> (sub := env => (
		out('> ')
		scan(line => (
			log(print(eval(read(line), env)))
			sub(env)
		))
	))(Env)
	_ -> (
		readFile(path, file => file :: {
			() -> log(f('error: could not read {{0}}', [path]))
			_ -> eval(read(file), Env)
		})
	)
}

