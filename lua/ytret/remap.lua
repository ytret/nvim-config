vim.g.mapleader = " "

vim.keymap.set("n", "<Space>", "<Nop>", { silent = true, desc = "Leader key" })

vim.keymap.set("n", "J", "mzJ`z", { desc = "Join lines without moving cursor" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up half a page and center" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down half a page and center" })
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search match and center" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Previous search match and center" })
vim.keymap.set("n", "Q", "<nop>", { desc = "Disable Ex mode" })
vim.keymap.set("n", "<leader>go", function()
    if vim.fn.executable("opengit") == 0 then
        vim.notify("opengit: executable not found in PATH", vim.log.levels.ERROR)
        return
    end

    local cwd = vim.fn.getcwd(-1, 0)
    local args = { "opengit" }
    local path = vim.api.nvim_buf_get_name(0)
    if vim.bo.buftype == "" and path ~= "" then
        vim.list_extend(args, { "--line", tostring(vim.api.nvim_win_get_cursor(0)[1]), path })
    else
        table.insert(args, cwd)
    end

    local ok, err = pcall(vim.system, args, { cwd = cwd, text = true }, function(result)
        if result.code ~= 0 then
            vim.schedule(function()
                local detail = vim.trim(result.stderr or "")
                if detail == "" then
                    detail = "exited with code " .. result.code
                end
                vim.notify("opengit: " .. detail, vim.log.levels.ERROR)
            end)
        else
            local url = (result.stdout or ""):match("https?://%S+")
            if url then
                vim.schedule(function() vim.notify("Open " .. url, vim.log.levels.INFO) end)
            end
        end
    end)
    if not ok then
        vim.notify("opengit: " .. tostring(err), vim.log.levels.ERROR)
    end
end, { desc = "Open current file on Git remote" })

vim.keymap.set(
    "n",
    "<leader>bd",
    ":b# | bd #<cr>",
    { desc = "Delete buffer and switch to alternate" }
)

vim.keymap.set("n", "<leader>wq", vim.cmd.quit, { desc = "Close window" })
vim.keymap.set("n", "<leader>wv", vim.cmd.vsplit, { desc = "Split window vertically" })
vim.keymap.set("n", "<leader>wn", vim.cmd.vsplit, { desc = "Split window vertically" })
vim.keymap.set("n", "<leader>ws", vim.cmd.split, { desc = "Split window horizontally" })
vim.keymap.set("n", "<leader>wo", vim.cmd.only, { desc = "Close other windows" })
vim.keymap.set("n", "<leader>wh", ":vert help ", { desc = "Open help in vertical split" })

vim.keymap.set("", "<leader>y", '"+y', { desc = "Yank to system clipboard" })
vim.keymap.set("", "<leader>Y", '"+Y', { desc = "Yank line to system clipboard" })
vim.keymap.set("", "<leader>qy", '"+y', { desc = "Yank to system clipboard" })
vim.keymap.set("", "<leader>qY", '"+Y', { desc = "Yank line to system clipboard" })
vim.keymap.set("", "<leader>qd", '"+d', { desc = "Delete to system clipboard" })
vim.keymap.set("", "<leader>qD", '"+D', { desc = "Delete to end of line to system clipboard" })
vim.keymap.set("", "<leader>qp", '"+p', { desc = "Paste from system clipboard after cursor" })
vim.keymap.set("", "<leader>qP", '"+P', { desc = "Paste from system clipboard before cursor" })

vim.keymap.set("c", "<C-A>", "<Home>", { desc = "Go to start of command line" })
vim.keymap.set("c", "<C-F>", "<Right>", { desc = "Move right on command line" })
vim.keymap.set("c", "<C-B>", "<Left>", { desc = "Move left on command line" })
vim.keymap.set("c", "<C-D>", "<Delete>", { desc = "Delete character on command line" })
vim.keymap.set("c", "<Esc>f", "<S-Right>", { desc = "Next word on command line" })
vim.keymap.set("c", "<Esc>b", "<S-Left>", { desc = "Previous word on command line" })

-- Delete a single char, not a whole indent level. By default <BS> eats a full
-- 'softtabstop'/'shiftwidth' worth of indentation (see 'smarttab' + 'softtabstop').
local function delete_char_before_cursor()
    -- Insert-mode mappings also fire in Replace mode (see |map-modes|), where
    -- the vanilla <BS> undoes replace changes instead of deleting a character.
    -- Re-feed the key without remapping to keep the built-in behavior there.
    if vim.fn.mode(1):sub(1, 1) == "R" then
        vim.api.nvim_feedkeys(
            vim.api.nvim_replace_termcodes("<BS>", true, false, true),
            "nit",
            false
        )
        return
    end
    local row, byte_col = unpack(vim.api.nvim_win_get_cursor(0))
    if byte_col > 0 then
        local line = vim.api.nvim_get_current_line()
        local prefix = line:sub(1, byte_col)
        local nchar = vim.str_utfindex(prefix)
        local start = vim.str_byteindex(prefix, nchar - 1)
        vim.api.nvim_set_current_line(line:sub(1, start) .. line:sub(byte_col + 1))
        vim.api.nvim_win_set_cursor(0, { row, start })
    elseif row > 1 then
        -- At the start of a line: join with the previous line, like <BS> with 'eol'.
        local prev = vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1]
        local cur = vim.api.nvim_get_current_line()
        vim.api.nvim_buf_set_lines(0, row - 2, row, false, { prev .. cur })
        vim.api.nvim_win_set_cursor(0, { row - 1, #prev })
    end
end
vim.keymap.set("i", "<BS>", delete_char_before_cursor, { desc = "Delete previous character" })
vim.keymap.set("i", "<C-h>", delete_char_before_cursor, { desc = "Delete previous character" })

-- Remove whitespace (preserves cursor position, no jumplist/mark pollution)
vim.keymap.set("n", "<leader>rw", function()
    local save = vim.fn.winsaveview()
    local s = vim.fn.getreg("/")
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.setreg("/", s)
    vim.fn.winrestview(save)
end, { desc = "Remove trailing whitespace" })

vim.keymap.set(
    "n",
    "<leader>hl",
    function() vim.o.hlsearch = not vim.o.hlsearch end,
    { desc = "Toggle hlsearch" }
)
