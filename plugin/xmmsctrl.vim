" Plugin: xmmsctrl.vim
" Version: 0.1
" Purpose: simple XMMS control through 'smart' buffer
" Author: Andrew Rodionoff (arnost AT mail DOT ru)
" Requires: Vim 6.2+, xmmsctrl 1.6+ by Alexandre David. Search it on xmms.org.
"
" Usage: just put it in $VIM/plugins/ folder
"
" - For tighter integration with XMMS, configure its songchange plugin
"   to run a command like this (join lines):
"   for n in `vim --serverlist`;
"   do vim --servername "$n" --remote-expr 'XMMS_SongChanged()' ; done
"
" - Use command similar to:
"   vim --remote-expr 'XMMS_OpenPlaylist(0)'
"   to popup playlist editor from shell or window manager menu
"
" Variables:
"   g:XMMS_TagEncoding -- set it to some valid encoding name if needed
"   g:XMMS_AutoSqueeze -- set to 1 if you want playlist to shrink/unshrink
"                         automatically (annoyingly) on window leave/enter
"
" Bugs: ?
 
if v:version < 602
    finish
endif

fun! s:SongSelector(linenum)
    setlocal ma noswf noro bh=wipe nowrap
    silent %d
    0insert
# Press <Tab> to enter playlist edit mode
# Press <Enter> to play song at cursor
.
    syn match Comment '^#.*'
    if exists('g:XMMS_TagEncoding')
        let l:tenc = &fileencodings
        exec 'set fileencodings=' . g:XMMS_TagEncoding
    endif
    silent r!xmmsctrl playlist
    if exists('g:XMMS_TagEncoding')
        exec 'set fileencodings=' . l:tenc
    endif
    silent $d
    setlocal nomodifiable nomodified ro nobuflisted
    let s:in_selector = 1
    mapclear <buffer>
    map <silent> <buffer> <Tab> :call <SID>Playlist(line('.'))<CR>
    map <silent> <buffer> <Return> :call <SID>GotoSong()<CR>
    augroup XMMS
        au!
        au BufEnter \#\#XMMS\#\# call <SID>HiliteCurrent()
        if exists('g:XMMS_AutoSqueeze') && g:XMMS_AutoSqueeze == 1
            au WinLeave \#\#XMMS\#\# call <SID>AutoSqueeze()
        endif
    augroup END
    call s:HiliteCurrent()
    call s:CenterLine(a:linenum)
endfun

fun! s:AutoSqueeze()
    let l:wh = winheight(0)
    augroup XMMS
        exe 'au WinEnter ##XMMS## ' . l:wh . 'wincmd _'
    augroup END
    1wincmd _
    call s:CenterLine(-1)
endfun

fun! s:GotoSong()
    let l:nr = matchstr(getline('.'), '^[0-9]\+')
    if l:nr != ''
        call system('xmmsctrl track ' . l:nr)
    endif
endfun

fun! s:Playlist(linenum)
    setlocal modifiable noro bufhidden=hide nobuflisted
    silent %d
    let s:in_selector = 0
    0insert
# Press <Tab> to leave editor
# :w loads playlist into XMMS
.
    syn match Comment '^#.*'
    silent r!xmmsctrl playfiles
    silent! %s/^[0-9]\+\s*//g
    silent $d
    setlocal nomodified
    mapclear <buffer>
    map <silent> <buffer> <Tab> :call <SID>SongSelector(line('.'))<CR>
    augroup XMMS
        au!
        au BufWriteCmd \#\#XMMS\#\#  call <SID>SendPlaylist()
    augroup END
    call s:CenterLine(a:linenum)
endfun

fun! s:GotoWindow(winnum)
    let l:prev = winnr()
    while winnr() != a:winnum
        wincmd w
        if winnr() == l:prev
            return -1
        endif
    endwhile
    return l:prev
endfun

fun! s:SendPlaylist()
    if filewritable($HOME . '/.xmms/')
        let l:t = $HOME . '/.xmms/xmms.m3u'
    else
        let l:t = tempname()
    endif
    exe 'w! ' . l:t
    call system('xmms ' . l:t)
    setlocal nomodified
endfun

fun! s:CenterLine(num)
    if a:num != -1
        exe 'normal ' . a:num . 'zz'
    else
        if !exists('g:XMMS_playlist_pos')
            call s:UpdatePlayPos()
        endif
        exe 'normal ' . (g:XMMS_playlist_pos + 2) . 'zz'
    endif
endfun

fun! s:UpdatePlayPos()
    let g:XMMS_playlist_pos = matchstr(system('xmmsctrl getpos'), '[0-9]\+')
    if g:XMMS_playlist_pos == ''
        let g:XMMS_playlist_pos = 0
        return
    endif
endfun

fun! XMMS_SongChanged()
    call s:UpdatePlayPos()
    let l:xmms_win = bufwinnr("##XMMS##") 
    if l:xmms_win != -1 && s:in_selector
        let l:prev = s:GotoWindow(l:xmms_win)
        if prev != -1
            call s:HiliteCurrent()
            call s:CenterLine(-1)
            call s:GotoWindow(l:prev)
            redraw
        endif
    endif
endfun

fun! XMMS_OpenPlaylist(mode)
    call foreground()
    let l:xmms_win = bufwinnr('##XMMS##')
    if l:xmms_win == -1 || s:GotoWindow(l:xmms_win) == -1
        split \#\#XMMS\#\#
    endif
    if a:mode == 0
        call s:SongSelector(-1)
    else
        call s:Playlist(-1)
    endif
    redraw
endfun

fun! s:HiliteCurrent()
    if !exists('g:XMMS_playlist_pos')
        call s:UpdatePlayPos()
    endif
    silent! syn clear XMMSCurrent
    exe 'syn match XMMSCurrent keepend "^' . g:XMMS_playlist_pos . '\>.*$"'
    hi link XMMSCurrent Search
endfun

amenu <silent> &XMMS.&Song\ list    :call XMMS_OpenPlaylist(0)<CR>
amenu <silent> &XMMS.&File\ list    :call XMMS_OpenPlaylist(1)<CR>
