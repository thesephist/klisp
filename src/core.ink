` helpers for loading Klisp libraries `

std := load('../vendor/std')

clone := std.clone
readFile := std.readFile

klisp := load('klisp')

read := klisp.read
eval := klisp.eval
Env := klisp.Env

` bootstrapping function to boot up an environment with given libraries `
withLibs := (libs, cb) => (sub := (i, env) => i :: {
	len(libs) -> cb(env)
	_ -> readFile(libs.(i), file => (
		eval(read(file), env)
		sub(i + 1, env)
	))
})(0, clone(Env))

` boot up an environment with core libraries `
withCore := cb => withLibs([
	'./lib/klisp.klisp'
	'./lib/math.klisp'
], cb)

