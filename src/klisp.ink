` Klisp: a LISP written in Ink `

std := load('../vendor/std')
str := load('../vendor/str')

log := std.log
f := std.format
stringList := std.stringList
map := std.map
each := std.each
reduce := std.reduce
scan := std.scan
rf := std.readFile

digit? := str.digit?
letter? := str.letter?

Newline := char(10)
Tab := char(9)
logf := (s, x) => log(f(s, x))

reduceL := (L, f, init) => (sub := (acc, node) => node :: {
	() -> acc
	_ -> sub(f(acc, node.0), node.1)
})(init, L)

reader := s => (
	data := {s: s, i: 0}
	peek := () => s.(data.i)
	next := () => (
		c := peek()
		data.i := data.i + 1
		c
	)
	nextSpan := () => (
		(sub := acc => peek() :: {
			() -> acc
			' ' -> acc
			Newline -> acc
			Tab -> acc
			')' -> acc
			_ -> sub(acc + next())
		})('')
	)

	data.next := next
	data.nextSpan := nextSpan
	data.peek := peek
	data.ff := () => (
		(sub := () => (
			peek() :: {
				' ' -> (next(), sub())
				Newline -> (next(), sub())
				Tab -> (next(), sub())
				_ -> ()
			}
		))()
	)
)

` read takes a string and returns a List `
read := s => (
	r := reader(s)

	peek := r.peek
	next := r.next
	nextSpan := r.nextSpan
	ff := r.ff

	parse := () => c := peek() :: {
		() -> ()
		',' -> (
			next()
			ff()
			[',quote', [parse(), ()]]
		)
		'\'' -> (
			next()
			(sub := acc => peek() :: {
				() -> acc
				'\\' -> (next(), sub(acc + next()))
				'\'' -> (next(), ff(), acc)
				_ -> sub(acc + next())
			})('')
		)
		'(' -> (
			next()
			ff()
			(sub := (acc, tail) => peek() :: {
				() -> acc
				')' -> (next(), acc)
				'.' -> (
					next()
					ff()
					cons := parse()
					ff()
					acc := (acc :: {
						() -> cons
						_ -> (tail.1 := cons, acc)
					})
					sub(acc, cons)
				)
				_ -> (
					cons := [parse(), ()]
					ff()
					acc := (acc :: {
						() -> cons
						_ -> (tail.1 := cons, acc)
					})
					sub(acc, cons)
				)
			})((), ())
		)
		_ -> digit?(c) :: {
			true -> (
				span := nextSpan()
				ff()
				number(span)
			)
			false -> (
				span := ',' + nextSpan()
				ff()
				span
			)
		}
	}

	parse()
)

getenv := (env, name) => v := env.(name) :: {
	() -> e := env.('_env') :: {
		() -> ()
		_ -> getenv(e, name)
	}
	_ -> v
}

makeFn := f => () => [false, f]
makeMacro := f => () => [true, f]

eval := (L, env) => L :: {
	[',quote', _] -> (L.1).0
	[',def', _] -> (
		name := (L.1).0
		val := ((L.1).1).0
		env.(name) := eval(val, env)
		()
	)
	[',if', _] -> (
		cond := (L.1).0
		conseq := ((L.1).1).0
		altern := (((L.1).1).1).0
		eval(cond, env) :: {
			true -> eval(conseq, env)
			_ -> eval(altern, env)
		}
	)
	[',fn', _] -> (
		params := (L.1).0
		body := ((L.1).1).0
		makeFn(args => (
			envc := (sub := (envc, params, args) => [params, args] :: {
				[(), _] -> envc
				[_, ()] -> envc
				_ -> (
					arg := args.0
					param := params.0
					envc.(param) := arg
					sub(envc, params.1, args.1)
				)
			})({'_env': env}, params, args)
			eval(body, envc)
		))
	)
	[',macro', _] -> (
		params := (L.1).0
		body := ((L.1).1).0
		makeMacro(args => (
			envc := (sub := (envc, params, args) => [params, args] :: {
				[(), _] -> envc
				[_, ()] -> envc
				_ -> (
					arg := args.0
					param := params.0
					envc.(param) := arg
					sub(envc, params.1, args.1)
				)
				` NOTE: all arguments to a macro are passed as the first parameter `
			})({'_env': env}, params, [args, ()])
			eval(body, envc)
		))
	)
	_ -> type(L) :: {
		'composite' -> (
			func := L.0
			argcs := L.1

			funcStub := eval(func, env)()
			macro? := funcStub.0
			func := eval(funcStub.1, env)

			macro? :: {
				true -> (
					transformed := func(argcs)
					eval(transformed, env)
				)
				false -> (
					args := []
					reduceL(argcs, (head, x) => (
						cons := [eval(x, env)]
						head.1 := cons
						cons
					), args)
					func(args.1)
				)
			}
		)
		'string' -> L.0 :: {
			',' -> getenv(env, L)
			_ -> L
		}
		_ -> L
	}
}

Env := {
	',true': true
	',false': false
	',car': makeFn(L => (L.0).0)
	',cdr': makeFn(L => (L.0).1)
	',cons': makeFn(L => [L.0, (L.1).0])
	',print': makeFn(L => log(reduceL(L.1, (a, b) => a + ' ' + print(b), print(L.0))))
	',=': makeFn(L => reduceL(L.1, (a, b) => a = b, L.0))
	',<': makeFn(L => L.0 < (L.1).0)
	',>': makeFn(L => L.0 > (L.1).0)
	',+': makeFn(L => reduceL(L.1, (a, b) => a + b, L.0))
	',-': makeFn(L => reduceL(L.1, (a, b) => a - b, L.0))
	',*': makeFn(L => reduceL(L.1, (a, b) => a * b, L.0))
	',/': makeFn(L => reduceL(L.1, (a, b) => a / b, L.0))
	',%': makeFn(L => reduceL(L.1, (a, b) => a % b, L.0))
	',&': makeFn(L => reduceL(L.1, (a, b) => a & b, L.0))
	',|': makeFn(L => reduceL(L.1, (a, b) => a | b, L.0))
	',^': makeFn(L => reduceL(L.1, (a, b) => a ^ b, L.0))
}

print := L => type(L) :: {
	'composite' -> L :: {
		[_, ()] -> f('({{0}})', [print(L.0)])
		[_, _] -> f('({{0}} . {{1}})', [print(L.0), print(L.1)])
		_ -> stringList(L)
	}
	_ -> string(L)
}

