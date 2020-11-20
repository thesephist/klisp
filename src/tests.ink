std := load('../vendor/std')

log := std.log
f := std.format
each := std.each
reduce := std.reduce

klisp := load('klisp')

read := klisp.read
eval := klisp.eval
print := klisp.print
Env := klisp.Env

Newline := char(10)
logf := (s, x) => log(f(s, x))

log('::: READ TESTS :::')
Tests := [
	'240'
	'test-word'
	'()'
	'(x)'
	'(x . y)'
	'(a b)'
	'(x . (y . ()))'
	'(+ 1 23 45.6)'
	'((x) (y)( z))'
	'(+ . numbers)'
	'(a( b  c
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
		'(def doot (fn () (- 1000 (+ a a))))'
		'(doot)'
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
	',(10 20 30 40 50)'
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
	'(print 1 2 (+ 1 2) (* 3 4))'
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


