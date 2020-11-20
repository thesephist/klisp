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

ws? := str.ws?
digit? := str.digit?
letter? := str.letter?

Newline := char(10)
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
				' ' -> next()
				Newline -> next()
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

eval := L => L :: {
	',true' -> true
	',false' -> false
	[',+', _] -> reduceL(L.1, (a, b) => a + eval(b), type((L.1).0) :: {
		'number' -> 0
		'string' -> ''
	})
	[',-', _] -> reduceL((L.1).1, (a, b) => a - eval(b), eval((L.1).0))
	[',*', _] -> reduceL(L.1, (a, b) => a * eval(b), 1)
	[',/', _] -> reduceL((L.1).1, (a, b) => a / eval(b), eval((L.1).0))
	[',%', _] -> reduceL((L.1).1, (a, b) => a % eval(b), eval((L.1).0))
	[',car', _] -> eval((L.1).0)
	[',cdr', _] -> eval((L.1).1)
	[',cons', _] -> (
		car := (L.1).0
		cdr := ((L.1).1).0
		[eval(car), eval(cdr)]
	)
	[',if', _] -> (
		cond := (L.1).0
		conseq := ((L.1).1).0
		altern := (((L.1).1).1).0
		eval(cond) :: {
			true -> eval(conseq)
			_ -> eval(altern)
		}
	)
	[',quote', _] -> ()
	_ -> type(L) :: {
		'composite' -> (
			` TODO: apply function `
		)
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
	'()'
	'(x)'
	'(x . y)'
	'(a b)'
	'(x . (y . ()))'
	'(+ 1 23 45.6)'
	'((x) (y) (z))'
	'(a ( b  c d )e f g  )'
]
each(Tests, t => log(print(read(t))))

log('::: EVAL TESTS :::')
EvalTests := [
	'(+ 1 2 3 4 5)'
	'(- 100 (/ (* 10 10) 5) 40)'
	'(+ 4 (* 2 5))'
	'(+ \'Hello\' \' World\\\'s!\')'
	'(if true 2 3)'
]
each(EvalTests, t => log(eval(read(t))))

