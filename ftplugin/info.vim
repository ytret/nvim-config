if &buftype =~? 'nofile'
    nmap <buffer> gu <Plug>(InfoUp)
    nmap <buffer> gn <Plug>(InfoNext)
    nmap <buffer> gp <Plug>(InfoPrev)
endif

if &buftype =~? 'nofile'
    nmap <buffer> gm <Plug>(InfoMenu)
    nmap <buffer> gf <Plug>(InfoFollow)
    nmap <buffer> go <Plug>(InfoGoto)
endif
