" Script Name: mark.vim
" Version:     1.1.2
" Last Change: March 23, 2005
" Author:      Yuheng Xie <elephant@linux.net.cn>
"
" Description: a little script to highlight several words in different colors
"              simultaneously
"
" Usage:       call Mark(regexp) to mark a regular expression.
"              call Mark(regexp) with exactly the same regexp to unmark it.
"              call Mark() to clear all marks.
"
"              You may map keys for the call in your vimrc file for
"              convenience. The default keys is:
"              Highlighting:
"                Normal \m  mark or unmark the word under or before the cursor
"                       \r  manually input a regular expression
"                       \n  clear this mark (i.e. the mark under the cursor),
"                           or clear all marks
"                Visual \m  mark or unmark a visual selection
"              Searching:
"                Normal  *  jump to the next occurrence of this mark
"                        #  jump to the previous occurrence of this mark
"                combined with VIM's / and ? etc.
"
"              The default colors/groups setting is for marking six
"              different words in different colors. You may define your own
"              colors in your vimrc file. That is to define highlight group
"              names as "MarkWordN", where N is a number. An example could be
"              found below.
"
" Bugs:        some colored words could not be highlighted

" default colors/groups
" you may define your own colors in you vimrc file, in the form as below:
hi MarkWord1  ctermbg=Cyan     ctermfg=Black  guibg=#8CCBEA    guifg=Black
hi MarkWord2  ctermbg=Green    ctermfg=Black  guibg=#A4E57E    guifg=Black
hi MarkWord3  ctermbg=Yellow   ctermfg=Black  guibg=#FFDB72    guifg=Black
hi MarkWord4  ctermbg=Red      ctermfg=Black  guibg=#FF7272    guifg=Black
hi MarkWord5  ctermbg=Magenta  ctermfg=Black  guibg=#FFB3FF    guifg=Black
hi MarkWord6  ctermbg=Blue     ctermfg=Black  guibg=#9999FF    guifg=Black

" you may map keys to call Mark() in your vimrc file to trigger the functions.
" examples:
" mark or unmark the word under or before the cursor
nmap \m :let w=PrevWord()<bar>if w!=""<bar>cal Mark("\\<".w."\\>")<bar>en<cr>
" manually input a regular expression
nmap \r :cal inputsave()<bar>let r=input("@")<bar>cal inputrestore()<bar>if r!=""<bar>cal Mark(r)<bar>en<cr>
" clear the mark under the cursor, or clear all marks
nmap \n :cal Mark(ThisMark())<cr>
" jump to the next occurrence of this mark
nnoremap * :let w=ThisMark()<bar>if w!=""<bar>cal search(w)<bar>el<bar>exe "norm! *"<bar>en<cr>
" jump to the previous occurrence of this mark
nnoremap # :let w=ThisMark()<bar>if w!=""<bar>cal search(w,"b")<bar>el<bar>exe "norm! #"<bar>en<cr>
" mark or unmark a visual selection
vnoremap \m "my:cal Mark("\\V".substitute(@m,"\\n","\\\\n","g"))<cr>

" define variables if they don't exist
function! InitMarkVaribles()
	if !exists("g:mwCycleMax")
		let i = 1
		while hlexists("MarkWord" . i)
			let i = i + 1
		endwhile
		let g:mwCycleMax = i - 1
	endif
	if !exists("b:mwCycle")
		let b:mwCycle = 1
	endif
	let i = 1
	while i <= g:mwCycleMax
		if !exists("b:mwWord" . i)
			let b:mwWord{i} = ""
		endif
		let i = i + 1
	endwhile
endfunction

" return the word under or before the cursor
function! PrevWord()
	let line = getline(".")
	if line[col(".") - 1] =~ "\\w"
		return expand("<cword>")
	else
		return substitute(strpart(line, 0, col(".") - 1), "^.\\{-}\\(\\w\\+\\)\\W*$", "\\1", "")
	endif
endfunction

" mark or unmark a regular expression
function! Mark(...) " Mark(regexp)
	" define variables if they don't exist
	call InitMarkVaribles()

	" clear all marks if regexp is null
	let regexp = ""
	if a:0 > 0
		let regexp = a:1
	endif
	if regexp == ""
		let i = 1
		while i <= g:mwCycleMax
			if b:mwWord{i} != ""
				let b:mwWord{i} = ""
				exe "syntax clear MarkWord" . i
			endif
			let i = i + 1
		endwhile
		return
	endif

	" clear the mark if it has been marked
	let i = 1
	while i <= g:mwCycleMax
		if regexp == b:mwWord{i}
			let b:mwWord{i} = ""
			exe "syntax clear MarkWord" . i
			return
		endif
		let i = i + 1
	endwhile

	" add to history
	call histadd("/", regexp)
	call histadd("@", regexp)

	" quote regexp with / etc. e.g. pattern => /pattern/
	let quote = "/?~!@#$%^&*+-=,.:"
	let i = 0
	while i < strlen(quote)
		if stridx(regexp, strpart(quote, i, 1)) < 0
			let quoted_regexp = strpart(quote, i, 1) . regexp . strpart(quote, i, 1)
			break
		endif
		let i = i + 1
	endwhile
	if i >= strlen(quote)
		return
	endif

	" choose an unused mark group
	let i = 1
	while i <= g:mwCycleMax
		if b:mwWord{i} == ""
			let b:mwWord{i} = regexp
			if i < g:mwCycleMax
				let b:mwCycle = i + 1
			else
				let b:mwCycle = 1
			endif
			exe "syntax clear MarkWord" . i
			exe "syntax match MarkWord" . i . " " . quoted_regexp . " containedin=ALL"
			return
		endif
		let i = i + 1
	endwhile

	" choose a mark group by cycle
	let i = 1
	while i <= g:mwCycleMax
		if b:mwCycle == i
			let b:mwWord{i} = regexp
			if i < g:mwCycleMax
				let b:mwCycle = i + 1
			else
				let b:mwCycle = 1
			endif
			exe "syntax clear MarkWord" . i
			exe "syntax match MarkWord" . i . " " . quoted_regexp . " containedin=ALL"
			return
		endif
		let i = i + 1
	endwhile
endfunction

" return the mark string under the cursor. multi-lines marks not supported
function! ThisMark()
	" define variables if they don't exist
	call InitMarkVaribles()

	let line = getline(".")
	let i = 1
	while i <= g:mwCycleMax
		if b:mwWord{i} != ""
			let start = 0
			while start >= 0 && start < strlen(line) && start < col(".")
				let b = match(line, b:mwWord{i}, start)
				let e = matchend(line, b:mwWord{i}, start)
				if b < col(".") && col(".") <= e
					return b:mwWord{i}
				endif
				let start = e
			endwhile
		endif
		let i = i + 1
	endwhile
	return ""
endfunction

" vim: ts=2 sw=2
