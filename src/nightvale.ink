` utilities for the Nightvale interface `

klisp := load('klisp')

Quote := klisp.Quote
Def := klisp.Def
Do := klisp.Do
If := klisp.If
Fn := klisp.Fn
Macro := klisp.Macro

reduceL := klisp.reduceL
symbol? := klisp.symbol?
getenv := klisp.getenv
makeFn := klisp.makeFn
makeMacro := klisp.makeMacro

decrementer := n => (
	S := [n]
	() => (
		n := S.'0' - 1
		S.'0' := n
		n
	)
)

` a version of klisp's eval() that bails/errors if the interpreter
	evaluates more than some maximum number of forms, to avoid the interpreter
	getting stuck in infinite loops unrecoverably.

	Yes, this is not the ideal solution -- the "correct" solution would be to
	send a timeout signal to a separate thread, or something like that. Unfortunately,
	Ink doesn't have the right primitives to multithread like that, so we do this instead. `
safeEval := (L, env, dec) => dec() :: {
	0 -> ()
	_ -> type(L) :: {
		'composite' -> L.0 :: {
			Quote -> L.'1'.0
			Def -> (
				name := L.'1'.0
				val := safeEval(L.'1'.'1'.0, env, dec)
				env.(name) := val
				val
			)
			Do -> (sub := form => form.1 :: {
				() -> safeEval(form.0, env, dec)
				_ -> (
					safeEval(form.0, env, dec)
					sub(form.1)
				)
			})(L.1)
			If -> (
				cond := L.'1'.0
				conseq := L.'1'.'1'.0
				altern := L.'1'.'1'.'1'.0
				safeEval(cond, env, dec) :: {
					true -> safeEval(conseq, env, dec)
					_ -> safeEval(altern, env, dec)
				}
			)
			Fn -> (
				params := L.'1'.0
				body := L.'1'.'1'.0
				makeFn(args => safeEval(
					body
					(sub := (envc, params, args) => params = () | args = () :: {
						true -> envc
						_ -> (
							envc.(params.0) := args.0
							sub(envc, params.1, args.1)
						)
					})({'-env': env}, params, args)
					dec
				))
			)
			Macro -> (
				params := L.'1'.0
				body := L.'1'.'1'.0
				makeMacro(args => safeEval(
					body
					(sub := (envc, params, args) => params = () | args = () :: {
						true -> envc
						_ -> (
							envc.(params.0) := args.0
							sub(envc, params.1, args.1)
						)
						` NOTE: all arguments to a macro are passed as the first parameter `
					})({'-env': env}, params, [args, ()])
					dec
				))
			)
			_ -> (
				argcs := L.1
				funcStub := safeEval(L.0, env, dec)
				func := safeEval(funcStub.1, env, dec)

				` funcStub.0 reports whether a function is a macro `
				funcStub.0 :: {
					true -> safeEval(func(argcs), env, dec)
					_ -> (
						reduceL(argcs, (head, x) => (
							cons := [safeEval(x, env, dec)]
							head.1 := cons
							cons
						), args := [])
						func(args.1)
					)
				}
			)
		}
		'string' -> symbol?(L) :: {
			true -> getenv(env, L)
			_ -> L
		}
		_ -> L
	}
}

evalAtMostSteps := (L, env, steps) => safeEval(L, env, decrementer(steps))

