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
	'((x) (y)( z))'
	'(+ . numbers)'
	'(a ( b  c
		d )e f	g  )'
]
each(Tests, t => log(print(read(t))))

log('::: EVAL TESTS :::')
EvalTests := [
	'(& (= 3 3) (= 1 2))'
	'(+ 1 2 3 4 5)'
	'(+ . (1 2 3 4 5 6))'
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
	'((fn (x y z) (* x y z)) 2 3 10)'
	[
		'(def a 647)'
		'(+ a a)'
		'(def do (fn () (- 1000 (+ a a))))'
		'(do)'
	]
	[
		'(def add +)'
		'(def mul *)'
		'(mul (add 1 2 3) (mul 10 10))'
	]
	[
		'(def fib
			  (fn (n)
			      (if (< n 2)
					  1
					  (+ (fib (- n 1)) (fib (- n 2))))))'
		'(fib 10)'
	]
	'(quote 123)'
	'(quote (quote 1 2 3))'
	'(car (quote (quote 1 2 3)))'
	'(cdr (quote (quote 1 2 3)))'
	'(cons 100 (quote (200 300 400)))'
	[
		'(def map
			  (fn (list f)
			      (if (= list ())
				      ()
					  (cons (f (car list))
						    (map (cdr list) f)))))'
		'(def square (fn (x) (* x x)))'
		'(def nums (quote (1 2 3 4 5)))'
		'(map nums square)'
	]
	[
		'(def list
			  (macro (items)
					 (cons (quote quote)
						   (cons items ()))))'
		'(list 1 2 3 4 (+ 2 3))'
	]
	[
		'(def sum
			  (fn (xs)
				  (if (= xs ())
					  0
					  (+ (car xs) (sum (cdr xs))))))'
		'(def size
			  (fn (xs)
				  (if (= xs ())
					  0
					  (+ 1 (size (cdr xs))))))'
		'(def avg
			  (fn (xs)
				  (/ (sum xs) (size xs))))'
		'(avg (quote (100 200 300 500)))'
	]
]
each(EvalTests, t => type(t) :: {
	'string' -> logf('{{0}}' + Newline + '    -> {{1}}'
		[t, print(eval(read(t), Env))])
	'composite' -> reduce(t, (env, term, i) => (
		i :: {
			(len(t) - 1) -> logf('{{0}}' + Newline + '    -> {{1}}'
				[term, print(eval(read(term), env))])
			_ -> logf('{{0}}', [term, eval(read(term), env)])
		}
		env
	), Env)
	_ -> logf('Invalid test: {{0}}', [t])
})

