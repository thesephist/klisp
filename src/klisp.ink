` Link: a LISP written in Ink `

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

L := (car, cdr) => [car, cdr]
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
	data.back := () => data.i := data.i + 1
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

` Representing Ink values in Link syntax:
	- booleans, numbers, null, and strings are the same
	- vectors and maps are backed by composites `

` read takes a string and returns a List `
read := s => (
	r := reader(s)

	peek := r.peek
	next := r.next
	nextSpan := r.nextSpan
	back := r.back
	ff := r.ff

	parse := () => c := peek() :: {
		',' -> (
			next()
			ff()
			[',quote', parse()]
		)
		'\'' -> (
			next()
			(sub := acc => peek() :: {
				'\\' -> (next(), sub(acc + next()))
				'\'' -> (next(), ff(), acc)
				_ -> sub(acc + next())
			})('')
		)
		'(' -> (
			next()
			ff()
			(sub := (acc, tail) => peek() :: {
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

eval := (L, env) => L :: {
	',true' -> true
	',false' -> false
	[',=', _] -> reduceL((L.1).1, (a, b) => a = eval(b, env), eval((L.1).0, env))
	[',+', _] -> reduceL(L.1, (a, b) => a + eval(b, env), type((L.1).0) :: {
		'number' -> 0
		'string' -> ''
	})
	[',-', _] -> reduceL((L.1).1, (a, b) => a - eval(b, env), eval((L.1).0, env))
	[',*', _] -> reduceL(L.1, (a, b) => a * eval(b, env), 1)
	[',/', _] -> reduceL((L.1).1, (a, b) => a / eval(b, env), eval((L.1).0, env))
	[',%', _] -> reduceL((L.1).1, (a, b) => a % eval(b, env), eval((L.1).0, env))
	[',&', _] -> reduceL((L.1).1, (a, b) => a & eval(b, env), eval((L.1).0, env))
	[',|', _] -> reduceL((L.1).1, (a, b) => a | eval(b, env), eval((L.1).0, env))
	[',^', _] -> reduceL((L.1).1, (a, b) => a ^ eval(b, env), eval((L.1).0, env))
	[',car', _] -> eval((L.1).0, env)
	[',cdr', _] -> eval((L.1).1, env)
	[',cons', _] -> (
		car := (L.1).0
		cdr := ((L.1).1).0
		[eval(car, env), eval(cdr, env)]
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
		args => (
			envc := (sub := (envc, params, args) => params :: {
				() -> envc
				_ -> (
					arg := eval(args.0, env)
					param := params.0
					envc.(param) := arg
					sub(envc, params.1, args.1)
				)
			})({}, params, args)
			eval(body, envc)
		)
	)
	[',def', _] -> (
		name := (L.1).0
		val := ((L.1).1).0
		env.(name) := eval(val, env)
	)
	[',quote', _] -> L.1
	_ -> type(L) :: {
		'composite' -> (
			func := L.0
			args := L.1
			eval(func, env)(args)
		)
		'string' -> L.0 :: {
			',' -> x := env.(L) :: {
				() -> logf('Unbound name: {{0}}', [L])
				_ -> x
			}
			_ -> L
		}
		_ -> L
	}
}

print := L => type(L) :: {
	'composite' -> L :: {
		[_, ()] -> f('({{0}})', [print(L.0)])
		[_, _] -> f('({{0}} . {{1}})', [print(L.0), print(L.1)])
		_ -> stringList(L)
	}
	_ -> string(L)
}

log('::: READ TESTS :::')
Tests := [
	`` '10'
	`` 'word'
	'(+ 1
		2)'
	'()'
	'(x)'
	'(x . y)'
	'(a b)'
	'(x . (y . ()))'
	'(+ 1 23 45.6)'
	'((x) (y)( z))'
	'(a ( b  c
		d )e f	g  )'
]
each(Tests, t => log(print(read(t))))

log('::: EVAL TESTS :::')
EvalTests := [
	'(& (= 3 3) (= 1 2))'
	'(+ 1 2 3 4 5)'
	'(- 100 (/ (* 10 10) 5) 40)'
	'(+ 4 (* 2 5))'
	'(+ \'Hello\' \' World\\\'s!\')'
	'(if false 2 . (3))'
	'(if (& (= 3 3)
			(= 1 2))
		 (+ 1 2 3)
		 (* 4 5 6))'
	'((fn () \'result\') 100)'
	'((fn (x) (+ 1 x)) 2)'
	'((fn (x y) (* x y)) 2 10)'
]
each(EvalTests, t => log(eval(read(t), {})))

