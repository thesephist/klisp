#!/usr/bin/env ink

` Klisp CLI `

std := load('../vendor/std')

log := std.log
f := std.format
scan := std.scan
clone := std.clone
slice := std.slice
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

Version := '0.1'

withCore := cb => readFile('./lib/klisp.klisp', file => file :: {
	() -> log('error: could not locate standard library')
	_ -> (
		env := clone(Env)
		eval(read(file), env)
		cb(env)
	)
	_ -> cb(file)
})

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
						printResp := s => stdout.len(stdout) := s
						env.symbol('print') := makeFn(L => printResp(reduceL(
							L.1, (a, b) => a + ' ' + (type(b) :: {
								'string' -> b
								_ -> print(b)
							})
							type(L.0) :: {
								'string' -> L.0
								_ -> print(L.0)
							}
						)))

						out := print(eval(read(req.body), env))
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
					writeFile(dbPath, req.body, r => r :: {
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
					delete(dbPath, evt => evt :: {
						'data' -> ({
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

