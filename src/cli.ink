#!/usr/bin/env ink

` Klisp CLI `

std := load('../vendor/std')

log := std.log
f := std.format
scan := std.scan
clone := std.clone
slice := std.slice
cat := std.cat
map := std.map
readFile := std.readFile
writeFile := std.writeFile

klisp := load('klisp')

read := klisp.read
eval := klisp.eval
print := klisp.print
symbol := klisp.symbol
makeFn := klisp.makeFn
reduceL := klisp.reduceL
Env := klisp.Env

nightvale := load('nightvale')

safeEval := nightvale.evalAtMostSteps

Version := '0.1'
` after some testing, considering Go/Ink's stack limit,
	this seemed like a reasonable number for a web repl `
MaxWebReplSteps := 100000

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

Args := args()
Args.2 :: {
	'--port' -> number(Args.3) :: {
		() -> log(f('{{0}} is not a number', [Args.3]))
		_ -> withCore(env => (
			http := load('../vendor/http')
			mime := load('../vendor/mime')
			percent := load('../vendor/percent')

			mimeForPath := mime.forPath
			pctDecode := percent.decode

			server := (http.new)()
			MethodNotAllowed := {status: 405, body: 'method not allowed'}

			addRoute := server.addRoute
			addRoute('/eval', params => (req, end) => req.method :: {
				'POST' -> end({
					status: 200
					headers: {'Content-Type': 'text/plain'}
					body: (
						stdout := ''
						localEnv := clone(env)
						printResp := s => stdout.len(stdout) := s
						localEnv.symbol('print') := makeFn(L => printResp(reduceL(
							L.1, (a, b) => a + ' ' + (type(b) :: {
								'string' -> b
								_ -> print(b)
							})
							type(L.0) :: {
								'string' -> L.0
								_ -> print(L.0)
							}
						)))

						out := print(safeEval(read(req.body), localEnv, MaxWebReplSteps))
						log(f('(eval {{0}}) => {{1}}', [req.body, out]))
						stdout + out
					)
				})
				_ -> end(MethodNotAllowed)
			})
			addRoute('/doc/*docID', params => (req, end) => req.method :: {
				'GET' -> (
					dbPath := 'db/' + params.docID
					readFile(dbPath, file => file :: {
						() -> end({status: 404, body: 'doc not found'})
						_ -> end({
							status: 200
							headers: {'Content-Type': 'application/json'}
							body: file
						})
					})
				)
				'PUT' -> (
					dbPath := 'db/' + params.docID
					readFile(dbPath, file => file :: {
						() -> end({status: 404, body: 'doc not found'})
						_ -> writeFile(dbPath, req.body, r => r :: {
							true -> end({
								status: 200
								headers: {'Content-Type': 'text/plain'}
								body: '1'
							})
							_ -> end({
								status: 500
								body: 'error saving doc'
							})
						})
					})
				)
				'POST' -> (
					dbPath := 'db/' + params.docID
					readFile(dbPath, file => file :: {
						() -> writeFile(dbPath, req.body, r => r :: {
							true -> end({
								status: 200
								headers: {'Content-Type': 'text/plain'}
								body: '1'
							})
							_ -> end({
								status: 500
								body: 'error saving doc'
							})
						})
						_ -> end({
							status: 409
							headers: {'Content-Type': 'text/plain'}
							body: 'conflict'
						})
					})
				)
				'DELETE' -> (
					dbPath := 'db/' + params.docID
					delete(dbPath, evt => evt.type :: {
						'end' -> end({
							status: 204
							body: ''
						})
						'error' -> end({
							status: 500
							body: 'error deleting doc'
						})
					})
				)
				_ -> end(MethodNotAllowed)
			})
			addRoute('/doc/', params => (req, end) => req.method :: {
				'GET' -> dir('db', evt => evt.type :: {
					'error' -> end({
						status: 500
						body: 'error reading database'
					})
					_ -> end({
						status: 200
						headers: {'Content-Type': 'text/plain'}
						body: cat(map(evt.data, entry => entry.name), char(10))
					})
				})
				_ -> end(MethodNotAllowed)
			})

			serveStatic := path => (req, end) => req.method :: {
				'GET' -> (
					staticPath := 'static/' + path
					readFile(staticPath, file => file :: {
						() -> end({status: 404, body: 'file not found'})
						_ -> end({
							status: 200
							headers: {'Content-Type': mimeForPath(staticPath)}
							body: file
						})
					})
				)
				_ -> end(MethodNotAllowed)
			}
			addRoute('/static/*staticPath', params => serveStatic(params.staticPath))
			addRoute('/', params => serveStatic('index.html'))

			(server.start)(number(Args.3))
		))
	}
	` initialize environment and start `
	_ -> withCore(env => (
		paths := slice(args(), 2, len(args()))
		path := paths.0 :: {
			() -> (
				log(f('Klisp interpreter v{{0}}.', [Version]))
				(sub := env => (
					out('> ')
					scan(line => line :: {
						() -> log('EOF.')
						_ -> (
							log(print(eval(read(line), env)))
							sub(env)
						)
					})
				))(env)
			)
			_ -> readFile(path, file => file :: {
				() -> log(f('error: could not read {{0}}', [path]))
				_ -> eval(read(file), env)
			})
		}
	))
}

