local function upvalues(func)
    local t = {}
    local i = 1
    while true do
        local n, v = debug.getupvalue(func, i)
        if not n then
            break
        end
        t[n] = v
        i = i + 1
    end
    return t
end

local function noop() end
local function make_mapping() return noop end

local function cleanup()
    for _, a in ipairs(vim.api.nvim_get_autocmds({ event = "LspAttach" })) do
        if a.desc == "LSP actions" then
            pcall(vim.api.nvim_del_autocmd, a.id)
        end
    end
end

local function onewin()
    local wins = vim.api.nvim_tabpage_list_wins(0)
    for i = 2, #wins do
        pcall(vim.api.nvim_win_close, wins[i], false)
    end
end

describe("other_or_new_win", function()
    local other_or_new_win
    local wp

    before_each(function()
        wp = { pick_window = function() return nil end }
        package.loaded["yt-window-picker"] = wp

        package.loaded["cmp"] = {
            SelectBehavior = { Select = 1 },
            setup = noop,
            mapping = {
                preset = { insert = function(m) return m end },
                complete = make_mapping,
                select_prev_item = make_mapping,
                select_next_item = make_mapping,
                abort = make_mapping,
                confirm = make_mapping,
                scroll_docs = make_mapping,
            },
            config = { sources = function(s) return s end },
        }
        package.loaded["mason"] = { setup = function() end }
        package.loaded["mason-lspconfig"] = { setup = function() end }
        package.loaded["luasnip"] = { lsp_expand = function() end }
        vim.lsp.config = function() end

        dofile("after/plugin/lsp.lua")
        local aucmds = vim.api.nvim_get_autocmds({ event = "LspAttach" })
        local callback = aucmds[#aucmds].callback
        other_or_new_win = upvalues(upvalues(callback).def_in_other_win).other_or_new_win
    end)

    after_each(function()
        cleanup()
        onewin()
    end)

    it("returns the other window when exactly 2 normal windows exist", function()
        local b = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_win_set_buf(0, b)
        vim.cmd("split")
        local curr = vim.api.nvim_tabpage_get_win(0)
        local result = other_or_new_win()
        assert.is_not.equals(curr, result)
        assert.is_true(vim.api.nvim_win_is_valid(result))
    end)

    it("creates a vsplit and returns a valid window when only 1 window exists", function()
        assert.equals(1, #vim.api.nvim_tabpage_list_wins(0))
        local result = other_or_new_win()
        assert.is_true(vim.api.nvim_win_is_valid(result))
        assert.equals(2, #vim.api.nvim_tabpage_list_wins(0))
    end)

    it("delegates to pick_window when more than 2 windows exist", function()
        wp.pick_window = function() return 42 end
        local b = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_win_set_buf(0, b)
        vim.cmd("split")
        vim.cmd("vsplit")
        assert.equals(42, other_or_new_win())
    end)

    it("filters out floating windows when counting", function()
        local b = vim.api.nvim_create_buf(true, false)
        vim.cmd("split")
        vim.api.nvim_open_win(b, false, {
            relative = "editor",
            width = 10,
            height = 10,
            row = 0,
            col = 0,
            style = "minimal",
        })
        local curr = vim.api.nvim_tabpage_get_win(0)
        local result = other_or_new_win()
        assert.is_not.equals(curr, result)
    end)
end)

describe("def_in_target", function()
    local def_in_target
    local handler

    before_each(function()
        package.loaded["cmp"] = {
            SelectBehavior = { Select = 1 },
            setup = noop,
            mapping = {
                preset = { insert = function(m) return m end },
                complete = make_mapping,
                select_prev_item = make_mapping,
                select_next_item = make_mapping,
                abort = make_mapping,
                confirm = make_mapping,
                scroll_docs = make_mapping,
            },
            config = { sources = function(s) return s end },
        }
        package.loaded["mason"] = { setup = function() end }
        package.loaded["mason-lspconfig"] = { setup = function() end }
        package.loaded["luasnip"] = { lsp_expand = function() end }
        package.loaded["yt-window-picker"] = { pick_window = function() return nil end }
        package.loaded["ytret.path"] = {
            bufadd_prefer_rel = function(p)
                local b = vim.fn.bufadd(p)
                vim.bo[b].buflisted = true
                return b
            end,
            set_buf_listed = function(b)
                if not b or not vim.api.nvim_buf_is_valid(b) then
                    return false
                end
                vim.api.nvim_set_current_buf(b)
                vim.bo[b].buflisted = true
                vim.cmd.stopinsert()
                return true
            end,
        }
        vim.lsp.config = function() end
        vim.lsp.util = vim.lsp.util or {}
        vim.lsp.util.make_position_params = function() return {} end
        vim.lsp.buf_request = function(_, _, _, h) handler = h end

        dofile("after/plugin/lsp.lua")
        local aucmds = vim.api.nvim_get_autocmds({ event = "LspAttach" })
        local cb = aucmds[#aucmds].callback
        def_in_target = upvalues(upvalues(cb).def_in_other_win).def_in_target
    end)

    after_each(function()
        cleanup()
        onewin()
    end)

    it("stops on LSP error and does not call bufadd_prefer_rel", function()
        local bufadd_called = false
        package.loaded["ytret.path"].bufadd_prefer_rel = function()
            bufadd_called = true
            return 0
        end
        def_in_target(function() return 1000 end)
        handler({ message = "test error" }, nil, nil)
        assert.is_false(bufadd_called)
    end)

    it("stops on nil result and does not call bufadd_prefer_rel", function()
        local bufadd_called = false
        package.loaded["ytret.path"].bufadd_prefer_rel = function()
            bufadd_called = true
            return 0
        end
        def_in_target(function() return 1000 end)
        handler(nil, nil, nil)
        assert.is_false(bufadd_called)
    end)

    it("stops on empty list and does not call bufadd_prefer_rel", function()
        local bufadd_called = false
        package.loaded["ytret.path"].bufadd_prefer_rel = function()
            bufadd_called = true
            return 0
        end
        def_in_target(function() return 1000 end)
        handler(nil, {}, nil)
        assert.is_false(bufadd_called)
    end)

    it("stops on unsupported def shape and does not call bufadd_prefer_rel", function()
        local bufadd_called = false
        package.loaded["ytret.path"].bufadd_prefer_rel = function()
            bufadd_called = true
            return 0
        end
        def_in_target(function() return 1000 end)
        handler(nil, { uri = nil, range = nil }, nil)
        assert.is_false(bufadd_called)
    end)

    it("returns early when open_target returns nil", function()
        local bufadd_called = false
        package.loaded["ytret.path"].bufadd_prefer_rel = function()
            bufadd_called = true
            return 0
        end
        def_in_target(function() return nil end)
        handler(nil, {
            uri = "file:///tmp/x.lua",
            range = { start = { line = 0, character = 0 } },
        }, nil)
        assert.is_false(bufadd_called)
    end)

    it("uses first element when result is a list", function()
        local paths = {}
        package.loaded["ytret.path"].bufadd_prefer_rel = function(p)
            table.insert(paths, p)
            local b = vim.fn.bufadd(p)
            vim.bo[b].buflisted = true
            return b
        end
        local b = vim.api.nvim_create_buf(true, false)
        local w = vim.api.nvim_open_win(b, false, {
            relative = "editor",
            width = 10,
            height = 10,
            row = 0,
            col = 0,
            style = "minimal",
        })
        def_in_target(function() return w end)
        handler(nil, {
            { uri = "file:///tmp/first.lua", range = { start = { line = 0, character = 0 } } },
            { uri = "file:///tmp/second.lua", range = { start = { line = 0, character = 0 } } },
        }, nil)
        assert.equals("/tmp/first.lua", paths[1])
    end)

    it("loads the definition buffer on success", function()
        local b = vim.api.nvim_create_buf(true, false)
        local w = vim.api.nvim_open_win(b, false, {
            relative = "editor",
            width = 10,
            height = 10,
            row = 0,
            col = 0,
            style = "minimal",
        })
        -- Create a buffer with enough lines for cursor row 6 (line 5 + 1)
        local nb = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_lines(nb, 0, -1, false, {
            "a",
            "b",
            "c",
            "d",
            "e",
            "f",
            "g",
        })
        package.loaded["ytret.path"].bufadd_prefer_rel = function() return nb end
        def_in_target(function() return w end)
        handler(nil, {
            uri = "file:///tmp/def_test.lua",
            range = { start = { line = 5, character = 3 } },
        }, nil)
        assert.equals(nb, vim.api.nvim_win_get_buf(w))
    end)

    it("skips set_buf_listed when target window already has the definition buffer", function()
        local def_bufnr = vim.fn.bufadd("/tmp/def_skip.lua")
        vim.bo[def_bufnr].buflisted = true
        local w = vim.api.nvim_open_win(def_bufnr, false, {
            relative = "editor",
            width = 10,
            height = 10,
            row = 0,
            col = 0,
            style = "minimal",
        })
        local listed_count = 0
        package.loaded["ytret.path"].set_buf_listed = function()
            listed_count = listed_count + 1
            return true
        end
        def_in_target(function() return w end)
        handler(nil, {
            uri = "file:///tmp/def_skip.lua",
            range = { start = { line = 0, character = 0 } },
        }, nil)
        assert.equals(0, listed_count)
    end)

    it("stops processing when set_buf_listed fails", function()
        local b = vim.api.nvim_create_buf(true, false)
        local w = vim.api.nvim_open_win(b, false, {
            relative = "editor",
            width = 10,
            height = 10,
            row = 0,
            col = 0,
            style = "minimal",
        })
        package.loaded["ytret.path"].set_buf_listed = function() return false end
        local cursor_set = false
        local orig = vim.api.nvim_win_set_cursor
        vim.api.nvim_win_set_cursor = function() cursor_set = true end
        def_in_target(function() return w end)
        handler(nil, {
            uri = "file:///tmp/other.lua",
            range = { start = { line = 0, character = 0 } },
        }, nil)
        assert.is_false(cursor_set)
        vim.api.nvim_win_set_cursor = orig
    end)
end)
