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

local function close_tab()
    if vim.fn.tabpagenr("$") == 1 then
        print("Cannot close the last tab")
    else
        vim.cmd.tabclose()
    end
end

-- Open/close a tab
vim.keymap.set("n", "<leader>tt", open_current_buffer_in_new_tab)
vim.keymap.set("n", "<leader>tq", close_tab)
vim.keymap.set("n", "<leader>tc", close_tab)

-- Go to the prev/next/last tab
vim.keymap.set("n", "<leader>tp", vim.cmd.tabprev)
vim.keymap.set("n", "<leader>tn", vim.cmd.tabnext)
vim.keymap.set("n", "<M-[>", vim.cmd.tabprev)
vim.keymap.set("n", "<M-]>", vim.cmd.tabnext)
vim.keymap.set("n", "<leader>tl", "g<tab>")

-- Go to tab N
local function gen_tabn(num)
    return function()
        local last_tabnr = vim.fn.tabpagenr("$")
        if num <= last_tabnr then
            vim.cmd.tabn(string.format("%d", num))
        else
            print(string.format("Tab %d does not exist", num))
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

local function rtl_components(dir)
    local parts = {}
    while dir ~= "" and dir ~= "." and dir ~= "/" do
        parts[#parts + 1] = vim.fn.fnamemodify(dir, ":t")
        dir = vim.fn.fnamemodify(dir, ":h")
    end
    return parts
end

local function tab_label(tabnr)
    local buflist = vim.fn.tabpagebuflist(tabnr)
    local winnr = vim.fn.tabpagewinnr(tabnr)
    local bufnr = buflist[winnr]
    local bufname = vim.api.nvim_buf_get_name(bufnr)

    if bufname == "" then
        return "[No Name]"
    end

    local tail = vim.fn.fnamemodify(bufname, ":t")

    local all = {}
    for t = 1, vim.fn.tabpagenr("$") do
        local bl = vim.fn.tabpagebuflist(t)
        local name = vim.api.nvim_buf_get_name(bl[vim.fn.tabpagewinnr(t)])
        if name ~= "" then
            all[#all + 1] = name
        end
    end

    local group = {}
    for _, p in ipairs(all) do
        if vim.fn.fnamemodify(p, ":t") == tail then
            group[#group + 1] = p
        end
    end

    if #group <= 1 then
        return tail
    end

    local comps, max = {}, 0
    for i, p in ipairs(group) do
        comps[i] = rtl_components(vim.fn.fnamemodify(p, ":h"))
        if #comps[i] > max then
            max = #comps[i]
        end
    end

    local col = 0
    while col < max do
        local first
        local same = true
        for _, parts in ipairs(comps) do
            local v = parts[col + 1]
            if v ~= nil then
                if first == nil then
                    first = v
                elseif v ~= first then
                    same = false
                    break
                end
            end
        end
        if not same then
            break
        end
        col = col + 1
    end

    local idx
    for i, p in ipairs(group) do
        if p == bufname then
            idx = i
            break
        end
    end

    local prefix = idx and col < max and comps[idx][col + 1]
    return prefix and (prefix .. ":" .. tail) or tail
end

function M.tabline()
    local parts = {}
    local cur = vim.fn.tabpagenr()

    for tabnr = 1, vim.fn.tabpagenr("$") do
        if tabnr > 1 then
            table.insert(parts, "%#TabLineFill#|")
        end

        table.insert(parts, string.format(
            "%%%dT%%#TabLine# %d %s%s%%#TabLine# ",
            tabnr, tabnr,
            tabnr == cur and "%#TabLineSel#" or "%#TabLine#",
            tab_label(tabnr)
        ))
    end

    table.insert(parts, "%#TabLineFill#%T")
    return table.concat(parts)
end

vim.o.tabline = "%!v:lua.require'ytret.tabs'.tabline()"

return M
