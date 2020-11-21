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

s := (load('../vendor/suite').suite)(
	'Klisp language and standard library'
)

` short helper functions on the suite `
m := s.mark
t := s.test

` used for both read and print tests `
SyntaxTests := [
	['freestanding number'
		'240', 240]
	['freestanding symbol'
		'test-word', ',test-word']
	['freestanding null'
		'()', ()]
	['single symbol form'
		'(x)', [',x', ()]]
	['cons of symbols'
		'(x . y)', [',x', ',y']]
	['escaped strings'
		'(+ \'Hello\' \' World\\\'s!\')', [',+', ['Hello', [' World\'s!', ()]]]]
	['list of symbols'
		'(a b c)', [',a', [',b', [',c', ()]]]]
	['list of symbols in cons'
		'(x . (y . ()))', [',x', [',y', ()]]]
	['list numbers'
		'(+ 1 23 45.6)', [',+', [1, [23, [45.6, ()]]]]]
	['nested lists'
		'((x) (y)( z))', [[',x', ()], [[',y', ()], [[',z', ()], ()]]]]
	[
		'Multiline whitespaces'
		'(a( b  ' + Newline + 'c )d    e  )'
		[',a', [[',b', [',c', ()]], [',d', [',e', ()]]]]
	]
	[
		'Comments ignored by reader'
		'(a b ; (more sexprs)' + Newline + '; (x (y . z))' +
			Newline + '; (e f g)' + Newline + 'c)'
		[',a', [',b', [',c', ()]]]
	]
]

` used for eval tests `
EvalTests := [
	['', '(& (= 3 3) (= 1 2))', false]
	['', '(+ 1 2 3 4 5)', 15]
	['', '(+ . (1 2 3 4 5 6))', 21]
	['', '(- 100 (/ (* 10 10) 5) 40)', 40]
	['', '(+ 4 (* 2 5))', 14]
	['', '(+ \'Hello\' \' World\\\'s!\')', 'Hello World\'s!']
	['', '(if false 2 . (3))', 3]
	['', '(if (& (= 3 3)
			(= 1 2))
		 (+ 1 2 3)
		 (* 4 5 6))', 120]
	['', '((fn () \'result\') 100)', 'result']
	['', '((fn (x) (+ 1 x)) 2)', 3]
	['', '((fn (x y z) (* x y z)) 2 3 10)', 60]
	['', [
		'(def a 647)'
		'(+ a a)'
		'(def doot (fn () (- 1000 (+ a a))))'
		'(doot)'
	], ~294]
	['', [
		'(def add +)'
		'(def mul *)'
		'(mul (add 1 2 3) (mul 10 10))'
	], 600]
	['', [
		'(def fib
			  (fn (n)
			      (if (< n 2)
					  1
					  (+ (fib (- n 1)) (fib (- n 2))))))'
		'(fib 10)'
	], 89]
	['', '(quote 123)', 123]
	['', ',(10 20 30 40 50)', [10, [20, [30, [40, [50, ()]]]]]]
	['', '(quote (quote 1 2 3))', [',quote', [1, [2, [3, ()]]]]]
	['', '(car (quote (quote 1 2 3)))', ',quote']
	['', '(cdr (quote (quote 1 2 3)))', [1, [2, [3, ()]]]]
	['', '(cons 100 (quote (200 300 400)))', [100, [200, [300, [400, ()]]]]]
	['', [
		'(def map
			  (fn (xs f)
			      (if (= xs ())
				      ()
					  (cons (f (car xs))
						    (map (cdr xs) f)))))'
		'(def square (fn (x) (* x x)))'
		'(def nums (quote (1 2 3 4 5)))'
		'(map nums square)'
	], [1, [4, [9, [16, [25, ()]]]]]]
	['', [
		'(def list
			  (macro (items)
					 (cons (quote quote)
						   (cons items ()))))'
		'(list 1 2 3 4 (+ 2 3))'
	], [1, [2, [3, [4, [[',+', [2, [3, ()]]], ()]]]]]]
	['', [
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
	], 275]
]


m('read')
(
	each(SyntaxTests, term => (
		msg := term.0
		line := term.1
		sexpr := term.2
		t(msg, (read(line).1).0, sexpr)
	))
)

m('eval')
(
	each(EvalTests, testEval := term => (
		msg := term.0
		prog := term.1
		val := term.2
		type(prog) :: {
			'string' -> t(msg, eval(read(prog), Env), val)
			'composite' -> reduce(prog, (env, term, i) => (
				i :: {
					(len(prog) - 1) -> t(msg, eval(read(term), env), val)
					_ -> eval(read(term), env)
				}
				env
			), Env)
			_ -> log(f('error: invalid eval test {{0}}', [prog]))
		}
	))
)

m('print')
(
	each(SyntaxTests, term => (
		msg := term.0
		line := term.1
		sexpr := term.2
		` because syntax in SyntaxTests is not normalized,
			we read twice here to normalize `
		t(msg, read(print((read(line).1).0)), read(line))
	))
)

` end test suite, print result `
(s.end)()

