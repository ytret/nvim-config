local tabs = require("ytret.tabs")

describe("tabs", function()
    before_each(function()
        while vim.fn.tabpagenr("$") > 1 do
            vim.cmd("tabclose 2")
        end

        local wins = vim.api.nvim_list_wins()
        for i = #wins, 2, -1 do
            if vim.api.nvim_win_is_valid(wins[i]) then
                vim.api.nvim_win_close(wins[i], false)
            end
        end

        vim.cmd("split")
        vim.cmd("close")

        local buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_set_current_buf(buf)

        for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(b) and b ~= buf then
                vim.api.nvim_buf_delete(b, { force = true })
            end
        end
    end)

    describe("tabline()", function()
        it("shows the buffer name for a single window", function()
            local buf = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(buf, "/tmp/foo")
            vim.api.nvim_set_current_buf(buf)

            local result = tabs.tabline()
            assert.truthy(result:find("foo"),
                "Expected 'foo' in tabline, got: " .. tostring(result))
        end)

        it("shows the original buffer when a floating window is active", function()
            local buf = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(buf, "/tmp/bar")
            vim.api.nvim_set_current_buf(buf)

            local fzf_buf = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(fzf_buf, "/tmp/main")
            local float_win = vim.api.nvim_open_win(fzf_buf, true, {
                relative = "editor",
                width = 40,
                height = 10,
                row = 5,
                col = 5,
                style = "minimal",
            })
            assert.truthy(float_win, "Failed to create floating window")

            local result = tabs.tabline()
            assert.truthy(result:find("bar"),
                "Expected 'bar' in tabline, got: " .. tostring(result))
            assert.falsy(result:find("main"),
                "Did NOT expect 'main' in tabline, got: " .. tostring(result))

            vim.api.nvim_win_close(float_win, true)
        end)

        it("falls back to a non-terminal buffer in the tabpage", function()
            local orig_win = vim.api.nvim_get_current_win()

            local baz_buf = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(baz_buf, "/tmp/baz")
            vim.api.nvim_set_current_buf(baz_buf)

            vim.cmd("split")
            local split_win = vim.api.nvim_get_current_win()
            assert.are_not.equal(orig_win, split_win)

            local term_buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_open_term(term_buf, {})

            vim.api.nvim_set_current_win(orig_win)
            vim.api.nvim_set_current_buf(term_buf)

            local result = tabs.tabline()
            assert.truthy(result:find("baz"),
                "Expected 'baz' in tabline (non-terminal fallback), got: " .. tostring(result))
        end)

        it("shows [No Name] for unnamed buffers", function()
            local buf = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_set_current_buf(buf)

            local result = tabs.tabline()
            assert.truthy(result:find("[No Name]", 1, true),
                "Expected '[No Name]' in tabline, got: " .. tostring(result))
        end)

        it("does not error after closing and recreating tabs", function()
            vim.cmd("tabnew")
            vim.cmd("tabprev")
            vim.cmd("tabclose")
            vim.cmd("tabnew")

            local ok, result = pcall(tabs.tabline)
            assert.is_true(ok, "tabline() should not error after close/reopen tabs")
            assert.truthy(result:find("%1T", 1, true),
                "tab 1 should appear in tabline, got: " .. tostring(result))
            assert.truthy(result:find("%2T", 1, true),
                "tab 2 should appear in tabline, got: " .. tostring(result))
        end)

        it("handles multiple tabpages", function()
            local buf1 = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(buf1, "/tmp/foo")
            vim.api.nvim_set_current_buf(buf1)

            vim.cmd("tabnew")
            local buf2 = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(buf2, "/tmp/bar")
            vim.api.nvim_set_current_buf(buf2)

            vim.cmd("tabprev")
            local result1 = tabs.tabline()
            assert.truthy(result1:find("foo"),
                "Tab 1 expected 'foo', got: " .. tostring(result1))

            vim.cmd("tabnext")
            local result2 = tabs.tabline()
            assert.truthy(result2:find("bar"),
                "Tab 2 expected 'bar', got: " .. tostring(result2))
        end)
    end)
end)
