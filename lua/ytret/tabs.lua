local M = {}

local function open_current_buffer_in_new_tab()
    local view = vim.fn.winsaveview()
    local bufname = vim.api.nvim_buf_get_name(0)
    local has_file = bufname ~= ""

    if has_file then
        vim.cmd.tabnew("%")
        vim.fn.winrestview(view)
        return
    end

    vim.cmd.tabnew()
end

-- Open/close a tab
vim.keymap.set("n", "<leader>tt", open_current_buffer_in_new_tab)
vim.keymap.set("n", "<leader>tq", vim.cmd.tabclose)
vim.keymap.set("n", "<leader>tc", vim.cmd.tabclose)

-- Go to the prev/next/last tab
vim.keymap.set("n", "<leader>tp", vim.cmd.tabprev)
vim.keymap.set("n", "<leader>tn", vim.cmd.tabnext)
vim.keymap.set("n", "<M-[>", vim.cmd.tabprev)
vim.keymap.set("n", "<M-]>", vim.cmd.tabnext)
vim.keymap.set("n", "<leader>tl", "g<tab>")

-- Go to tab N
local function gen_tabn(num)
    return function()
        if num <= #vim.api.nvim_list_tabpages() then
            vim.cmd.tabn(string.format("%d", num))
        end
    end
end
vim.keymap.set("n", "<M-1>", gen_tabn(1))
vim.keymap.set("n", "<M-2>", gen_tabn(2))
vim.keymap.set("n", "<M-3>", gen_tabn(3))
vim.keymap.set("n", "<M-4>", gen_tabn(4))
vim.keymap.set("n", "<M-5>", gen_tabn(5))
vim.keymap.set("n", "<M-6>", gen_tabn(6))
vim.keymap.set("n", "<M-7>", gen_tabn(7))
vim.keymap.set("n", "<M-8>", gen_tabn(8))
vim.keymap.set("n", "<M-9>", gen_tabn(9))

local function tab_label(tabnr)
    local buflist = vim.fn.tabpagebuflist(tabnr)
    local winnr = vim.fn.tabpagewinnr(tabnr)
    local bufnr = buflist[winnr]
    local bufname = vim.api.nvim_buf_get_name(bufnr)

    if bufname == "" then
        return "[No Name]"
    end

    return vim.fn.fnamemodify(bufname, ":t")
end

function M.tabline()
    local parts = {}

    for tabnr = 1, vim.fn.tabpagenr("$") do
        local is_current = tabnr == vim.fn.tabpagenr()
        local hl = is_current and "%#TabLineSel#" or "%#TabLine#"

        table.insert(parts, string.format("%%%dT%s %s ", tabnr, hl, tab_label(tabnr)))
    end

    table.insert(parts, "%#TabLineFill#%T")
    return table.concat(parts)
end

vim.o.tabline = "%!v:lua.require'ytret.tabs'.tabline()"

return M
