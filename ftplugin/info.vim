if &buftype =~? 'nofile'
    lua vim.keymap.set("n", "gu", "<Plug>(InfoUp)", { buffer = true, remap = true, desc = "Info: parent node" })
    lua vim.keymap.set("n", "gn", "<Plug>(InfoNext)", { buffer = true, remap = true, desc = "Info: next node" })
    lua vim.keymap.set("n", "gp", "<Plug>(InfoPrev)", { buffer = true, remap = true, desc = "Info: previous node" })
endif

if &buftype =~? 'nofile'
    lua vim.keymap.set("n", "gm", "<Plug>(InfoMenu)", { buffer = true, remap = true, desc = "Info: menu" })
    lua vim.keymap.set("n", "gf", "<Plug>(InfoFollow)", { buffer = true, remap = true, desc = "Info: follow reference" })
    lua vim.keymap.set("n", "go", "<Plug>(InfoGoto)", { buffer = true, remap = true, desc = "Info: go to node" })
endif
