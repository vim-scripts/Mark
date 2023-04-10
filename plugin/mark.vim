" Script Name: mark.vim
" Version:     1.2.2 (global version)
" Last Change: January 30, 2019
" Author:      Yuheng Xie <thinelephant@gmail.com>
" Contributor: Luc Hermitte
"
" Description: a little script to highlight several words in different colors
"              simultaneously
"
" Usage:       :Mark regexp   to mark a regular expression
"              :Mark regexp   with exactly the same regexp to unmark it
"              :Mark          to mute all marks
"              :Mark          to show all marks again
"
"              You may map keys for the call in your vimrc file for
"              convenience. The default keys is:
"              Highlighting:
"                Normal \m  mark/unmark the word under the cursor,
"                           it clear all marks if state is muted
"                       \n  unmark the mark under the cursor,
"                           or mute/show all marks
"                       \r  manually input a regular expression
"                Visual \m  mark/unmark a visual selection
"                       \r  manually input a regular expression
"              Searching:
"                Normal \*  jump to the next occurrence of current mark
"                       \#  jump to the previous occurrence of current mark
"                       \/  jump to the next occurrence of ANY mark
"                       \?  jump to the previous occurrence of ANY mark
"                        *  behaviors vary,
"                        #  please refer to the table SEARCHING
"                combined with VIM's / and ? etc.
"
" Colors:      The default colors/groups setting is for marking six different
"              words in different colors. You may define your own colors in
"              your vimrc file. That is to define highlight group names as
"              "MarkWordN", where N is a number. An example could be found
"              below.
"
" Bugs:        some colored words could not be highlighted (on vim < 7.1)
"
" Changes:
" 30th Jan 2019, Yuheng Xie: default to muted when vim restarts
"
" 27th Jan 2019, Yuheng Xie: fix multi-lines pattern
"
" 14th Jan 2019, Yuheng Xie:
" (*) \n now mutes marks instead of clearing them, \m may clear them
" (*) marks are now savable if '!' exists in 'viminfo'
"
" 09th Jan 2019, Yuheng Xie: fix unnamed-register content after visual marking
"
" 21th Nov 2017, Yuheng Xie: fix error when no marks found
" (*) added exists() check when no marks found
" (*) changed default mark colors again
"
" 17th Dec 2016, Yuheng Xie: fix error in vim 6.4
" (*) added exists() check before calling vim 7 functions
" (*) changed default mark colors
"
" 16th Jan 2015, Yuheng Xie: add auto event WinEnter
" (*) added auto event WinEnter for reloading highlights after :split, etc.
"
" 29th Jul 2014, Yuheng Xie: call matchadd()
" (*) added call to VIM 7.1 matchadd(), make highlighting keywords possible
"
" 10th Mar 2006, Yuheng Xie: jump to ANY mark
" (*) added \* \# \/ \? for the ability of jumping to ANY mark, even when the
"     cursor is not currently over any mark
"
" 20th Sep 2005, Yuheng Xie: minor modifications
" (*) merged MarkRegexVisual into MarkRegex
" (*) added GetVisualSelectionEscaped for multi-lines visual selection and
"     visual selection contains ^, $, etc.
" (*) changed the name ThisMark to CurrentMark
" (*) added SearchCurrentMark and re-used raw map (instead of VIM function) to
"     implement * and #
"
" 14th Sep 2005, Luc Hermitte: modifications done on v1.1.4
" (*) anti-reinclusion guards. They do not guard colors definitions in case
"     this script must be reloaded after .gvimrc
" (*) Protection against disabled |line-continuation|s.
" (*) Script-local functions
" (*) Default keybindings
" (*) \r for visual mode
" (*) uses <leader> instead of "\"
" (*) do not mess with global variable g:w
" (*) regex simplified -> double quotes changed into simple quotes.
" (*) strpart(str, idx, 1) -> str[idx]
" (*) command :Mark
"     -> e.g. :Mark Mark.\{-}\ze(

function! s:RGB(r, g, b)
	return a:r * 36 + a:g * 6 + a:b + 16
endfunction

" default colors/groups
" you may define your own colors in you vimrc file, in the form as below:
if &t_Co < 256
	hi MarkWord1 guifg=White ctermfg=White guibg=#FF0000 ctermbg=Red
	hi MarkWord2 guifg=Black ctermfg=Black guibg=#FFD700 ctermbg=Yellow
	hi MarkWord3 guifg=Black ctermfg=Black guibg=#5FD700 ctermbg=Green
	hi MarkWord4 guifg=Black ctermfg=Black guibg=#00D7FF ctermbg=Cyan
	hi MarkWord5 guifg=White ctermfg=White guibg=#0087FF ctermbg=Blue
	hi MarkWord6 guifg=White ctermfg=White guibg=#AF00FF ctermbg=Magenta
else
	exec "hi MarkWord1 guifg=White ctermfg=White guibg=#FF0000 ctermbg=".s:RGB(5,0,0)
	exec "hi MarkWord2 guifg=Black ctermfg=Black guibg=#FFD700 ctermbg=".s:RGB(5,4,0)
	exec "hi MarkWord3 guifg=Black ctermfg=Black guibg=#5FD700 ctermbg=".s:RGB(1,4,0)
	exec "hi MarkWord4 guifg=Black ctermfg=Black guibg=#00D7FF ctermbg=".s:RGB(0,4,5)
	exec "hi MarkWord5 guifg=White ctermfg=White guibg=#0087FF ctermbg=".s:RGB(0,2,5)
	exec "hi MarkWord6 guifg=White ctermfg=White guibg=#AF00FF ctermbg=".s:RGB(3,0,5)
endif

" Anti reinclusion guards
if exists('g:loaded_mark') && !exists('g:force_reload_mark')
	finish
endif

" Support for |line-continuation|
let s:save_cpo = &cpo
set cpo&vim

" Default bindings

if !hasmapto('<Plug>MarkSet', 'n')
	nmap <unique> <silent> <leader>m <Plug>MarkSet
endif
if !hasmapto('<Plug>MarkSet', 'v')
	vmap <unique> <silent> <leader>m <Plug>MarkSet
endif
if !hasmapto('<Plug>MarkRegex', 'n')
	nmap <unique> <silent> <leader>r <Plug>MarkRegex
endif
if !hasmapto('<Plug>MarkRegex', 'v')
	vmap <unique> <silent> <leader>r <Plug>MarkRegex
endif
if !hasmapto('<Plug>MarkClear', 'n')
	nmap <unique> <silent> <leader>n <Plug>MarkClear
endif

nnoremap <silent> <Plug>MarkSet   :call
	\ <sid>MarkCurrentWord()<cr>
vnoremap <silent> <Plug>MarkSet   <c-\><c-n>:call
	\ <sid>DoMark(<sid>GetVisualSelectionEscaped("enV"))<cr>
nnoremap <silent> <Plug>MarkRegex :call
	\ <sid>MarkRegex()<cr>
vnoremap <silent> <Plug>MarkRegex <c-\><c-n>:call
	\ <sid>MarkRegex(<sid>GetVisualSelectionEscaped("N"))<cr>
nnoremap <silent> <Plug>MarkClear :call
	\ <sid>DoMark(<sid>CurrentMark())<cr>

" SEARCHING
"
" Here is a sumerization of the following keys' behaviors:
" 
" First of all, \#, \? and # behave just like \*, \/ and *, respectively,
" except that \#, \? and # search backward.
"
" \*, \/ and *'s behaviors differ base on whether the cursor is currently
" placed over an active mark:
"
"       Cursor over mark                  Cursor not over mark
" ---------------------------------------------------------------------------
"  \*   jump to the next occurrence of    jump to the next occurrence of
"       current mark, and remember it     "last mark".
"       as "last mark".
"
"  \/   jump to the next occurrence of    same as left
"       ANY mark.
"
"   *   if \* is the most recently used,  do VIM's original *
"       do a \*; otherwise (\/ is the
"       most recently used), do a \/.

nnoremap <silent> <leader>* :call <sid>SearchCurrentMark()<cr>
nnoremap <silent> <leader># :call <sid>SearchCurrentMark("b")<cr>
nnoremap <silent> <leader>/ :call <sid>SearchAnyMark()<cr>
nnoremap <silent> <leader>? :call <sid>SearchAnyMark("b")<cr>
nnoremap <silent> * :if !<sid>SearchNext()<bar>execute "norm! *"<bar>endif<cr>
nnoremap <silent> # :if !<sid>SearchNext("b")<bar>execute "norm! #"<bar>endif<cr>

command! -nargs=? Mark call s:DoMark(<f-args>)

autocmd! BufWinEnter,WinEnter * call s:UpdateMark()

" Functions

function! s:MarkCurrentWord()
	let w = s:PrevWord()
	if w != ""
		call s:DoMark('\<' . w . '\>')
	endif
endfunction

function! s:GetVisualSelection()
	let save_unamed = getreg('"')
	silent normal! gv""y
	let res = getreg('"')
	call setreg('"', save_unamed)
	return res
endfunction

function! s:GetVisualSelectionEscaped(flags)
	" flags:
	"  "e" \  -> \\  
	"  "n" \n -> \\n  for multi-lines visual selection
	"  "N" \n removed
	"  "V" \V added   for marking plain ^, $, etc.
	let result = s:GetVisualSelection()
	let i = 0
	while i < strlen(a:flags)
		if a:flags[i] ==# "e"
			let result = escape(result, '\')
		elseif a:flags[i] ==# "n"
			let result = substitute(result, '\n', '\\n', 'g')
		elseif a:flags[i] ==# "N"
			let result = substitute(result, '\n', '', 'g')
		elseif a:flags[i] ==# "V"
			let result = '\V' . result
		endif
		let i = i + 1
	endwhile
	return result
endfunction

" manually input a regular expression
function! s:MarkRegex(...) " MarkRegex(regexp)
	let regexp = ""
	if a:0 > 0
		let regexp = a:1
	endif
	call inputsave()
	let r = input("@", regexp)
	call inputrestore()
	if r != ""
		call s:DoMark(r)
	endif
endfunction

" define variables if they don't exist
function! s:InitMarkVariables()
	if !exists("g:mw_state")
		let g:mw_state = 0
	endif
	if !exists("g:MW_HIST_ADD")
		let g:MW_HIST_ADD = "/@"
	endif
	if !exists("g:MW_CYCLE_MAX")
		let i = 1
		while hlexists("MarkWord" . i)
			let i = i + 1
		endwhile
		let g:MW_CYCLE_MAX = i - 1
	endif
	if !exists("g:MW_CYCLE")
		let g:MW_CYCLE = 1
	endif
	let i = 1
	while i <= g:MW_CYCLE_MAX
		if !exists("g:MW_WORD" . i)
			let g:MW_WORD{i} = ""
		endif
		let i = i + 1
	endwhile
	if !exists("g:MW_LAST_SEARCHED")
		let g:MW_LAST_SEARCHED = ""
	endif
endfunction

" return the word under or before the cursor
function! s:PrevWord()
	let line = getline(".")
	if line[col(".") - 1] =~ '\w'
		return expand("<cword>")
	else
		return substitute(strpart(line, 0, col(".") - 1), '^.\{-}\(\w\+\)\W*$', '\1', '')
	endif
endfunction

" mark or unmark a regular expression
function! s:DoMark(...) " DoMark(regexp)
	" define variables if they don't exist
	call s:InitMarkVariables()

	" clear all marks if g:mw_state is 0 (i.e. muted) and regexp is not null
	let regexp = ""
	if a:0 > 0
		let regexp = a:1
	endif
	if regexp == ""
		let g:mw_state = 1 - g:mw_state
		call s:UpdateMark()
		if g:mw_state >= 1
			echo ""
		else
			echo "MarkWord muted"
		endif
		return 0
	elseif g:mw_state <= 0 && regexp != ""
		let g:mw_state = 1
		echo ""
		let i = 1
		while i <= g:MW_CYCLE_MAX
			if g:MW_WORD{i} != ""
				let g:MW_WORD{i} = ""
				let lastwinnr = winnr()
				if exists("*winsaveview")
					let winview = winsaveview()
				endif
				if exists("*matchdelete")
					windo silent! call matchdelete(3333 + i)
				else
					exe "windo syntax clear MarkWord" . i
				endif
				exe lastwinnr . "wincmd w"
				if exists("*winrestview")
					call winrestview(winview)
				endif
			endif
			let i = i + 1
		endwhile
	endif

	" clear the mark if it has been marked
	let i = 1
	while i <= g:MW_CYCLE_MAX
		if regexp == g:MW_WORD{i}
			if g:MW_LAST_SEARCHED == g:MW_WORD{i}
				let g:MW_LAST_SEARCHED = ""
			endif
			let g:MW_WORD{i} = ""
			let lastwinnr = winnr()
			if exists("*winsaveview")
				let winview = winsaveview()
			endif
			if exists("*matchdelete")
				windo silent! call matchdelete(3333 + i)
			else
				exe "windo syntax clear MarkWord" . i
			endif
			exe lastwinnr . "wincmd w"
			if exists("*winrestview")
				call winrestview(winview)
			endif
			return 0
		endif
		let i = i + 1
	endwhile

	" add to history
	if stridx(g:MW_HIST_ADD, "/") >= 0
		call histadd("/", regexp)
	endif
	if stridx(g:MW_HIST_ADD, "@") >= 0
		call histadd("@", regexp)
	endif

	" quote regexp with / etc. e.g. pattern => /pattern/
	let quote = "/?~!@#$%^&*+-=,.:"
	let i = 0
	while i < strlen(quote)
		if stridx(regexp, quote[i]) < 0
			let quoted_regexp = quote[i] . regexp . quote[i]
			break
		endif
		let i = i + 1
	endwhile
	if i >= strlen(quote)
		return -1
	endif

	" choose an unused mark group
	let i = 1
	while i <= g:MW_CYCLE_MAX
		if g:MW_WORD{i} == ""
			let g:MW_WORD{i} = regexp
			if i < g:MW_CYCLE_MAX
				let g:MW_CYCLE = i + 1
			else
				let g:MW_CYCLE = 1
			endif
			let lastwinnr = winnr()
			if exists("*winsaveview")
				let winview = winsaveview()
			endif
			if exists("*matchadd")
				windo silent! call matchdelete(3333 + i)
				windo silent! call matchadd("MarkWord" . i, g:MW_WORD{i}, -10, 3333 + i)
			else
				exe "windo syntax clear MarkWord" . i
				" suggested by Marc Weber, use .* instead off ALL
				exe "windo syntax match MarkWord" . i . " " . quoted_regexp . " containedin=.*"
			endif
			exe lastwinnr . "wincmd w"
			if exists("*winrestview")
				call winrestview(winview)
			endif
			return i
		endif
		let i = i + 1
	endwhile

	" choose a mark group by cycle
	let i = 1
	while i <= g:MW_CYCLE_MAX
		if g:MW_CYCLE == i
			if g:MW_LAST_SEARCHED == g:MW_WORD{i}
				let g:MW_LAST_SEARCHED = ""
			endif
			let g:MW_WORD{i} = regexp
			if i < g:MW_CYCLE_MAX
				let g:MW_CYCLE = i + 1
			else
				let g:MW_CYCLE = 1
			endif
			let lastwinnr = winnr()
			if exists("*winsaveview")
				let winview = winsaveview()
			endif
			if exists("*matchadd")
				windo silent! call matchdelete(3333 + i)
				windo silent! call matchadd("MarkWord" . i, g:MW_WORD{i}, -10, 3333 + i)
			else
				exe "windo syntax clear MarkWord" . i
				" suggested by Marc Weber, use .* instead off ALL
				exe "windo syntax match MarkWord" . i . " " . quoted_regexp . " containedin=.*"
			endif
			exe lastwinnr . "wincmd w"
			if exists("*winrestview")
				call winrestview(winview)
			endif
			return i
		endif
		let i = i + 1
	endwhile
endfunction

" update mark colors
function! s:UpdateMark()
	" define variables if they don't exist
	call s:InitMarkVariables()

	let i = 1
	while i <= g:MW_CYCLE_MAX
		exe "syntax clear MarkWord" . i
		if g:mw_state >= 1 && g:MW_WORD{i} != ""
			" quote regexp with / etc. e.g. pattern => /pattern/
			let quote = "/?~!@#$%^&*+-=,.:"
			let j = 0
			while j < strlen(quote)
				if stridx(g:MW_WORD{i}, quote[j]) < 0
					let quoted_regexp = quote[j] . g:MW_WORD{i} . quote[j]
					break
				endif
				let j = j + 1
			endwhile
			if j >= strlen(quote)
				continue
			endif

			let lastwinnr = winnr()
			if exists("*winsaveview")
				let winview = winsaveview()
			endif
			if exists("*matchadd")
				windo silent! call matchdelete(3333 + i)
				windo silent! call matchadd("MarkWord" . i, g:MW_WORD{i}, -10, 3333 + i)
			else
				exe "windo syntax clear MarkWord" . i
				" suggested by Marc Weber, use .* instead off ALL
				exe "windo syntax match MarkWord" . i . " " . quoted_regexp . " containedin=.*"
			endif
			exe lastwinnr . "wincmd w"
			if exists("*winrestview")
				call winrestview(winview)
			endif
		elseif g:MW_WORD{i} != ""
			let lastwinnr = winnr()
			if exists("*winsaveview")
				let winview = winsaveview()
			endif
			if exists("*matchdelete")
				windo silent! call matchdelete(3333 + i)
			else
				exe "windo syntax clear MarkWord" . i
			endif
			exe lastwinnr . "wincmd w"
			if exists("*winrestview")
				call winrestview(winview)
			endif
		endif
		let i = i + 1
	endwhile
endfunction

" return the mark string under the cursor
function! s:CurrentMark()
	" define variables if they don't exist
	call s:InitMarkVariables()

	let saved_line = line(".")
	let saved_col  = col(".")
	let search_begin = saved_line>100?saved_line-100:1
	let search_end   = saved_line+100<line("$")?saved_line+100:line("$")

	let result = 0
	let i = 1
	while i <= g:MW_CYCLE_MAX
		if g:mw_state >= 1 && g:MW_WORD{i} != ""
			call cursor(search_begin, 1)
			let end_line = 0
			let end_col  = 0
			while !(end_line > saved_line || end_line == saved_line && end_col >= saved_col)
				let fwd = search(g:MW_WORD{i}, "eW", search_end)
				if fwd == 0 || end_line == line(".") && end_col == col(".")
					break
				endif
				let end_line = line(".")
				let end_col  = col(".")
			endwhile
			if !(end_line > saved_line || end_line == saved_line && end_col >= saved_col)
				let i = i + 1
				continue
			endif
			call cursor(end_line, end_col)
			let bwd = search(g:MW_WORD{i}, "cbW", search_begin)
			if bwd == 0
				let i = i + 1
				continue
			endif
			let begin_line = line(".")
			let begin_col  = col(".")
			if begin_line < saved_line || begin_line == saved_line && begin_col <= saved_col
				let s:current_mark_position = begin_line . "_" . begin_col
				let result = i
				break
			endif
		endif
		let i = i + 1
	endwhile

	call cursor(saved_line, saved_col)
	if result > 0
		return g:MW_WORD{result}
	endif
	return ""
endfunction

" search current mark
function! s:SearchCurrentMark(...) " SearchCurrentMark(flags)
	let flags = ""
	if a:0 > 0
		let flags = a:1
	endif
	let w = s:CurrentMark()
	if w != ""
		let p = s:current_mark_position
		call search(w, flags)
		call s:CurrentMark()
		if exists("s:current_mark_position") && p == s:current_mark_position
			call search(w, flags)
		endif
		let g:MW_LAST_SEARCHED = w
	else
		if g:MW_LAST_SEARCHED != ""
			call search(g:MW_LAST_SEARCHED, flags)
		else
			call s:SearchAnyMark(flags)
			let g:MW_LAST_SEARCHED = s:CurrentMark()
		endif
	endif
endfunction

" combine all marks into one regexp
function! s:AnyMark()
	" define variables if they don't exist
	call s:InitMarkVariables()

	let w = ""
	let i = 1
	while i <= g:MW_CYCLE_MAX
		if g:mw_state >= 1 && g:MW_WORD{i} != ""
			if w != ""
				let w = w . '\|' . g:MW_WORD{i}
			else
				let w = g:MW_WORD{i}
			endif
		endif
		let i = i + 1
	endwhile
	return w
endfunction

" search any mark
function! s:SearchAnyMark(...) " SearchAnyMark(flags)
	let flags = ""
	if a:0 > 0
		let flags = a:1
	endif
	let w = s:CurrentMark()
	if w != ""
		let p = s:current_mark_position
	else
		let p = ""
	endif
	let w = s:AnyMark()
	call search(w, flags)
	call s:CurrentMark()
	if exists("s:current_mark_position") && p == s:current_mark_position
		call search(w, flags)
	endif
	let g:MW_LAST_SEARCHED = ""
endfunction

" search last searched mark
function! s:SearchNext(...) " SearchNext(flags)
	let flags = ""
	if a:0 > 0
		let flags = a:1
	endif
	let w = s:CurrentMark()
	if w != ""
		if g:MW_LAST_SEARCHED != ""
			call s:SearchCurrentMark(flags)
		else
			call s:SearchAnyMark(flags)
		endif
		return 1
	else
		return 0
	endif
endfunction

" Restore previous 'cpo' value
let &cpo = s:save_cpo

" vim: ts=2 sw=2
