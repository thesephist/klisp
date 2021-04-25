std := load('../vendor/std')

log := std.log
f := std.format
each := std.each
map := std.map
reduce := std.reduce
flatten := std.flatten

klisp := load('klisp')

symbol := klisp.symbol
read := klisp.read
eval := klisp.eval
print := klisp.print
Env := klisp.Env

core := load('core')

withLibs := core.withLibs
withCore := core.withCore

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
		'test-word', symbol('test-word')]
	['freestanding null'
		'()', ()]
	['single symbol form'
		'(x)', [symbol('x'), ()]]
	['cons of symbols'
		'(x . y)', [symbol('x'), symbol('y')]]
	['escaped strings'
		'(+ \'Hello\' \' World\\\'s!\')', [symbol('+'), ['Hello', [' World\'s!', ()]]]]
	['list of symbols'
		'(a b c)', [symbol('a'), [symbol('b'), [symbol('c'), ()]]]]
	['list of symbols in cons'
		'(x . (y . ()))', [symbol('x'), [symbol('y'), ()]]]
	['list numbers'
		'(+ 1 23 45.6)', [symbol('+'), [1, [23, [45.6, ()]]]]]
	['nested lists'
		'((x) (y)( z))', [[symbol('x'), ()], [[symbol('y'), ()], [[symbol('z'), ()], ()]]]]
	[
		'Multiline whitespaces'
		'(a( b  ' + Newline + 'c )d    e  )'
		[symbol('a'), [[symbol('b'), [symbol('c'), ()]], [symbol('d'), [symbol('e'), ()]]]]
	]
	[
		'Comments ignored by reader'
		'(a b ; (more sexprs)' + Newline + '; (x (y . z))' +
			Newline + '; (e f g)' + Newline + 'c)'
		[symbol('a'), [symbol('b'), [symbol('c'), ()]]]
	]
	[
		'Lack of trailing parentheses'
		'(+ 1 (* 2 3)'
		[symbol('+'), [1, [[symbol('*'), [2, [3, ()]]], ()]]]
	]
	[
		'Too many trailing parentheses'
		'(+ 1 (* 2 3))))'
		[symbol('+'), [1, [[symbol('*'), [2, [3, ()]]], ()]]]
	]
]

` used for eval tests `
EvalTests := [
	['boolean equalities'
		'(& (= 3 3) (= 1 2))', false]
	['variadic boolean relations'
		'(list (& true true true)
			(& false true false)
			(| false false true)
			(| false false false)
			(^ true true false)
			(^ false false false))', [true, [false, [true, [false, [true, [false, ()]]]]]]]
	['variadic addition'
		'(+ 1 2 3 4 5)', 15]
	['basic arithmetic ops with single arguments'
		'(+ (+ 1) (- 2) (* 3) (/ 4) (# 5) (% 6))', 21]
	['variadic addition, cons'
		'(+ . (1 2 3 4 5 6))', 21]
	['mixed arithmetic'
		'(- 100 (/ (* 10 10) 5) 40)', 40]
	['string operations'
		'(+ \'Hello\' \' World\\\'s!\')', 'Hello World\'s!']
	['simple if form'
		'(if false 2 . (3))', 3]
	['complex if form'
		'(if (& (= 3 3)
			    (= 1 2))
			 (+ 1 2 3)
			 (* 4 5 6))', 120]
	['anonymous fns'
		'((fn () \'result\') 100)', 'result']
	['fn form returns a function'
		'(type (fn (x) (- 0 x)))', 'function']
	['anonymous fns with argument'
		'((fn (x) (+ 1 x)) 2)', 3]
	['anonymous fns with arguments'
		'((fn (x y z) (* x y z)) 2 3 10)', 60]
	['string->number'
		'(+ (string->number \'3.14\')
			(string->number \'20\')
			(string->number (+ \'10\' \'0\')))', 123.14]
	['string->number on invalid strings = 0'
		'(+ (string->number \'broken\')
			(string->number \'0.234h\')
			(string->number \'\'))', 0]
	['number->string'
		'(+ (number->string 1.23)
			(number->string 40)
			(number->string (- 100 90)))', '1.230000004010']
	['string->symbol'
		'(cons (string->symbol \'quote\') (string->symbol (+ \'hel\' \'lo\'))', [symbol('quote'), symbol('hello')]]
	['symbol->string'
		'(cons (symbol->string ,quote) (symbol->string (quote hello)))', ['quote', 'hello']]
	['define form', [
		'(def a 647)'
		'(+ a a)'
		'(def doot (fn () (- 1000 (+ a a))))'
		'(doot)'
	], ~294]
	['define form returns its operand'
		'(def some-data (quote (my 1 2 3)))', [symbol('my'), [1, [2, [3, ()]]]]]
	['aliased fns with define forms', [
		'(def add +)'
		'(def mul *)'
		'(mul (add 1 2 3) (mul 10 10))'
	], 600]
	['fibonacci generator', [
		'(def fib
			  (fn (n)
			      (if (< n 2)
					  1
					  (+ (fib (- n 1)) (fib (- n 2))))))'
		'(fib 10)'
	], 89]
	['literal quote'
		'(quote (123 . 456))', [123, 456]]
	['shorthand quote'
		',(10 20 30 40 50)', [10, [20, [30, [40, [50, ()]]]]]]
	['shorthand quote on symbols and atoms'
		'(list ,abc ,123 ,\'def\' ,())', [symbol('abc'), [123, ['def', [(), ()]]]]]
	['double quote'
		'(quote (quote 1 2 3))', [symbol('quote'), [1, [2, [3, ()]]]]]
	['car of quote'
		'(car (quote (quote 1 2 3)))', symbol('quote')]
	['cdr of quote'
		'(cdr (quote (quote 1 2 3)))', [1, [2, [3, ()]]]]
	['cons of quote'
		'(cons 100 (quote (200 300 400)))', [100, [200, [300, [400, ()]]]]]
	['map over list', [
		'(def map
			  (fn (xs f)
			      (if (= xs ())
				      ()
					  (cons (f (car xs))
						    (map (cdr xs) f)))))'
		'(def square (fn (x) (* x x)))'
		'(def nums ,(1 2 3 4 5))'
		'(map nums square)'
	], [1, [4, [9, [16, [25, ()]]]]]]
	['list macro', [
		'(def square (fn (x) (* x x)))'
		'(list 1 2 3 4 (+ 2 3) (list 1 2 3))'
	], [1, [2, [3, [4, [5, [[1, [2, [3, ()]]], ()]]]]]]]
	['let macro'
		'(let (a 10) (let (b 20) (* a b)))', 200]
	['let macro with shadowing'
		'(let (a 5) (let (b 20) (let (a 10) (* a b))))', 200]
	['sum, size, average'
		'(avg (quote (100 200 300 500)))', 275]
	[
		'builtin fn type'
		'(+ (type 0) (type \'hi\') (type ,hi) (type true) (type type) (type ()) (type ,(0)))'
		'numberstringsymbolbooleanfunction()list'
	]
	['builtin len on string'
		'(len \'hello\')', 5]
	['builtin len on symbol'
		'(len ,hello)', 5]
	['builtin len on invalid value'
		'(len 3)', 0]
	['gets in bounds'
		'(gets \'hello world\' 4 8)', 'o wo']
	['gets partial out of bounds'
		'(gets \'hello world\' 4 100)', 'o world']
	['gets completely out of bounds'
		'(gets \'hello world\' 50 100)', '']
	['sets!', [
		'(def s \'hello world\')'
		'(sets! s 6 \'klisp\')'
		's'
	], 'hello klisp']
	['sets! returns mutated string', [
		'(def s \'hello world\')'
		'(sets! s 6 \'klisp\')'
	], 'hello klisp']
	['sets! does not grow underlying string', [
		'(def s \'hello world\')'
		'(sets! s 6 \'klispers everywhere\')'
		's'
	], 'hello klisp']
	['builtin char'
		'(+ (char 10) (char 13))', char(10) + char(13)]
	[
		'builtin point'
		'(+ (point \'A\') (point \'B\') (point \'Zte\'))'
		point('A') + point('B') + point('Zte')
	]
]

` run tests with core libraries loaded `
withCore(env => (
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
				'string' -> t(msg, eval(read(prog), env), val)
				'composite' -> reduce(prog, (env, term, i) => (
					i :: {
						len(prog) - 1 -> t(msg, eval(read(term), env), val)
						_ -> eval(read(term), env)
					}
					env
				), env)
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
		` use EvalTests to test print, since they're more complex,
		but we need to first expand out multiline tests. `
		EvalTestLines := flatten(map(EvalTests, term => type(term.1) :: {
			'string' -> [term.1]
			_ -> term.1
		}))
		each(EvalTestLines, term => (
			msg := term
			line := term
			t(msg, read(print((read(line).1).0)), read(line))
		))
	)

	` end test suite, print result `
	(s.end)()
))

