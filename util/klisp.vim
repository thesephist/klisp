" place this in the init path (.vimrc)
" au BufNewFile,BufRead *.klisp set filetype=klisp

if exists("b:current_syntax")
    finish
endif

" auto-format on write
au BufWritePre *.klisp normal gg=G''

" klisp syntax definition for vi/vim
syntax sync fromstart

" lisp-style indentation
set lisp

" booleans
syntax keyword klispBoolean true false
highlight link klispBoolean Boolean

" numbers should be consumed first by identifiers, so comes before
syntax match klispNumber "\v-?\d+[.\d+]?"
highlight link klispNumber Number

" special forms
syntax keyword klispKeyword quote contained
syntax keyword klispKeyword def contained
syntax keyword klispKeyword if contained
syntax keyword klispKeyword fn contained
syntax keyword klispKeyword macro contained
highlight link klispKeyword Keyword

" functions
syntax match klispFunctionForm "\v\(\s*[A-Za-z0-9\-?!+*/:><=%&|]*" contains=klispFunctionName,klispKeyword
syntax match klispFunctionName "\v[A-Za-z0-9\-?!+*/:><=%&|]*" contained
highlight link klispFunctionName Function

syntax match klispDefinitionForm "\v\(\s*\:\s*(\(\s*)?[A-Za-z0-9\-?!+*/:><=%&|]*" contains=klispDefinition
syntax match klispDefinition "\v[A-Za-z0-9\-?!+*/:><=%&|]*" contained
highlight link klispDefinition Type

" strings
syntax region klispString start=/\v'/ skip=/\v(\\.|\r|\n)/ end=/\v'/
highlight link klispString String

" comment
" -- block
" -- line-ending comment
syntax match klispComment "\v;.*" contains=klispTodo
highlight link klispComment Comment
" -- shebang, highlighted as comment
syntax match klispShebangComment "\v^#!.*"
highlight link klispShebangComment Comment
" -- TODO in comments
syntax match klispTodo "\v(TODO\(.*\)|TODO)" contained
syntax keyword klispTodo XXX contained
highlight link klispTodo Todo

syntax region klispForm start="(" end=")" transparent fold
set foldmethod=syntax
set foldlevel=20

let b:current_syntax = "klisp"
