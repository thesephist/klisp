` Klisp: a LISP written in Ink `

std := load('../vendor/std')
str := load('../vendor/str')

log := std.log
slice := std.slice
cat := std.cat
map := std.map
every := std.every

digit? := str.digit?
replace := str.replace
trim := str.trim

Newline := char(10)
Tab := char(9)
NUL := char(0)

` helper function. Like std.reduce, but traverses a list of sexprs `
reduceL := (L, f, init) => (sub := (acc, node) => node :: {
	() -> acc
	_ -> sub(f(acc, node.0), node.1)
})(init, L)

` turns a name into a Klisp symbol (prefixed with a ,) `
symbol := s => NUL + s

` takes a string, reports whether the string is a Klisp
	symbol (starts with a NUL byte) or not `
symbol? := s => s.0 = NUL

` memoized symbols (optimization) `
Quote := symbol('quote')
Do := symbol('do')
Def := symbol('def')
If := symbol('if')
Fn := symbol('fn')
Macro := symbol('macro')

` reader object constructor,
	state containing a cursor through a string `
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
			'(' -> acc
			')' -> acc
			_ -> sub(acc + next())
		})('')
	)
	ff := () => (
		(sub := () => (
			peek() :: {
				' ' -> (next(), sub())
				Newline -> (next(), sub())
				Tab -> (next(), sub())
				` ignore / ff through comments `
				';' -> (sub := () => next() :: {
					() -> ()
					Newline -> ff()
					_ -> sub()
				})()
				_ -> ()
			}
		))()
	)

	data.peek := peek
	data.next := next
	data.nextSpan := nextSpan
	data.ff := ff
)

` read takes a string and returns a List representing the input sexpr `
read := s => (
	r := reader(trim(trim(s, ' '), Newline))

	peek := r.peek
	next := r.next
	nextSpan := r.nextSpan
	ff := r.ff

	` ff through possible comments at start `
	ff()

	parse := () => c := peek() :: {
		() -> () ` EOF `
		',' -> (
			next()
			ff()
			[Quote, [parse(), ()]]
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
		_ -> (
			span := nextSpan()
			ff()
			every(map(span, c => digit?(c) | c = '.')) :: {
				true -> number(span)
				_ -> symbol(span)
			}
		)
	}

	term := [parse(), ()]
	prog := [Do, term]
	(sub := tail => peek() :: {
		() -> prog
		_ -> (
			term := [parse(), ()]
			tail.1 := term
			sub(term)
		)
	})(term)
)

` helper to query an environment (scope) for a name.
	getenv traverses the environment hierarchy `
getenv := (env, name) => v := env.(name) :: {
	() -> (
		` first do a more thorough check to see
			if the value is in scope but null () `
		boundNames := keys(env)
		bound? := (sub := i => i :: {
			len(boundNames) -> false
			_ -> boundNames.(i) :: {
				name -> true
				_ -> sub(i + 1)
			}
		})(0)
		bound? :: {
			true -> ()
			_ -> e := env.('-env') :: {
				() -> ()
				_ -> getenv(e, name)
			}
		}
	)
	_ -> v
}

` Klisp has two kinds of values represented as "functions".

	1. Functions, defined by (fn ...). Klisp functions take finite
		arguments evaluated eagerly in-scope.
	2. Macros, defined by (macro ...) Klisp macros take a sexpr List
		containing the arguments and returns some new piece of syntax.
		Arguments are not evaluated before call.

	In Klisp, fns and macros are represented as size-3 arrays to differentiate
	from 2-element arrays that represent sexprs. The first value reports
	whether the function is a macro or a normal function, and the second
	value is the actual function. `
makeFn := f => [false, f, ()]
makeMacro := f => [true, f, ()]

` the evaluator `
eval := (L, env) => type(L) :: {
	'composite' -> L.0 :: {
		Quote -> L.'1'.0
		Def -> (
			name := L.'1'.0
			val := eval(L.'1'.'1'.0, env)
			env.(name) := val
			val
		)
		Do -> (sub := form => form.1 :: {
			() -> eval(form.0, env)
			_ -> (
				eval(form.0, env)
				sub(form.1)
			)
		})(L.1)
		If -> (
			cond := L.'1'.0
			conseq := L.'1'.'1'.0
			altern := L.'1'.'1'.'1'.0
			eval(cond, env) :: {
				true -> eval(conseq, env)
				_ -> eval(altern, env)
			}
		)
		Fn -> (
			params := L.'1'.0
			body := L.'1'.'1'.0
			makeFn(args => eval(
				body
				(sub := (envc, params, args) => params = () | args = () :: {
					true -> envc
					_ -> (
						envc.(params.0) := args.0
						sub(envc, params.1, args.1)
					)
				})({'-env': env}, params, args)
			))
		)
		Macro -> (
			params := L.'1'.0
			body := L.'1'.'1'.0
			makeMacro(args => eval(
				body
				(sub := (envc, params, args) => params = () | args = () :: {
					true -> envc
					_ -> (
						envc.(params.0) := args.0
						sub(envc, params.1, args.1)
					)
					` NOTE: all arguments to a macro are passed as the first parameter `
				})({'-env': env}, params, [args, ()])
			))
		)
		_ -> (
			argcs := L.1
			funcStub := eval(L.0, env)
			func := eval(funcStub.1, env)

			` funcStub.0 reports whether a function is a macro `
			funcStub.0 :: {
				true -> eval(func(argcs), env)
				_ -> (
					reduceL(argcs, (head, x) => (
						cons := [eval(x, env)]
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

` the default environment contains core constants and functions `
Env := {
	` constants and fundamental forms `
	symbol('true'): true
	symbol('false'): false
	symbol('car'): makeFn(L => L.'0'.0)
	symbol('cdr'): makeFn(L => L.'0'.1)
	symbol('cons'): makeFn(L => [L.0, L.'1'.0])
	symbol('len'): makeFn(L => type(L.0) :: {
		'string' -> symbol?(L.0) :: {
			true -> len(L.0) - 1
			_ -> len(L.0)
		}
		_ -> 0
	})

	` direct ports of monotonic Ink functions `
	symbol('char'): makeFn(L => char(L.0))
	symbol('point'): makeFn(L => point(L.0))
	symbol('sin'): makeFn(L => sin(L.0))
	symbol('cos'): makeFn(L => cos(L.0))
	symbol('floor'): makeFn(L => floor(L.0))
	symbol('rand'): makeFn(rand)
	symbol('time'): makeFn(time)

	` arithmetic and logical operators `
	symbol('='): makeFn(L => reduceL(L.1, (a, b) => a = b, L.0))
	symbol('<'): makeFn(L => reduceL(L.1, (a, b) => a < b, L.0))
	symbol('>'): makeFn(L => reduceL(L.1, (a, b) => a > b, L.0))
	symbol('+'): makeFn(L => reduceL(L.1, (a, b) => a + b, L.0))
	symbol('-'): makeFn(L => reduceL(L.1, (a, b) => a - b, L.0))
	symbol('*'): makeFn(L => reduceL(L.1, (a, b) => a * b, L.0))
	symbol('#'): makeFn(L => reduceL(L.1, (a, b) => pow(a, b), L.0))
	symbol('/'): makeFn(L => reduceL(L.1, (a, b) => a / b, L.0))
	symbol('%'): makeFn(L => reduceL(L.1, (a, b) => a % b, L.0))
	symbol('&'): makeFn(L => reduceL(L.1, (a, b) => a & b, L.0))
	symbol('|'): makeFn(L => reduceL(L.1, (a, b) => a | b, L.0))
	symbol('^'): makeFn(L => reduceL(L.1, (a, b) => a ^ b, L.0))

	` types and conversions `
	symbol('type'): makeFn(L => type(L.0))
	symbol('string->number'): makeFn(L => (
		operand := L.0
		type(operand) :: {
			'string' -> every(map(operand, c => digit?(c) | c = '.')) :: {
				true -> number(operand)
				_ -> 0
			}
			_ -> 0
		}
	))
	symbol('number->string'): makeFn(L => string(L.0))

	` I/O and system `
	symbol('print'): makeFn(L => out(reduceL(
		L.1, (a, b) => a + ' ' + (type(b) :: {
			'string' -> b
			_ -> print(b)
		})
		type(L.0) :: {
			'string' -> L.0
			_ -> print(L.0)
		}
	)))
}

` the printer
	print prints a value as sexprs, preferring lists and falling back to (a . b) `
print := L => L :: {
	[_, _] -> (
		list := (sub := (term, acc) => term :: {
			[_, [_, _]] -> (
				acc.len(acc) := print(term.0)
				sub(term.1, acc)
			)
			[_, ()] -> acc.len(acc) := print(term.0)
			[_, _] -> (
				acc.len(acc) := print(term.0)
				acc.len(acc) := '.'
				sub(term.1, acc)
			)
			_ -> acc.len(acc) := print(term)
		})(L, [])
		'(' + cat(list, ' ') + ')'
	)
	[_, _, _] -> '(function)'
	_ -> type(L) :: {
		'string' -> symbol?(L) :: {
			true -> slice(L, 1, len(L))
			_ -> '\'' + replace(replace(L, '\\', '\\\\'), '\'', '\\\'') + '\''
		}
		_ -> string(L)
	}
}

