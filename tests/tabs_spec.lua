local tabprompt = require("ytret.tabprompt")
local tabs = require("ytret.tabs")

describe("tabs", function()
    before_each(function()
        tabs._reset_cwd_groups()
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

    describe("open_in_picked_tab", function()
        local saved_prompt

        before_each(function()
            saved_prompt = tabprompt.prompt_for_tab
            -- Ensure we have exactly 3 tabs, on tab 2
            while vim.fn.tabpagenr("$") < 3 do
                vim.cmd("tabnew")
            end
            while vim.fn.tabpagenr("$") > 3 do
                vim.cmd("tabclose 4")
            end
            vim.cmd("tabnext 2")
            assert.are.equal(3, vim.fn.tabpagenr("$"))
            assert.are.equal(2, vim.fn.tabpagenr())
        end)

        after_each(function()
            tabprompt.prompt_for_tab = saved_prompt
        end)

        it("creates a new tab at the end when prompt returns { new = 'end' }", function()
            tabprompt.prompt_for_tab = function() return { new = "end" } end

            tabs.open_in_picked_tab(function() end)

            assert.are.equal(4, vim.fn.tabpagenr("$"))
            assert.are.equal(4, vim.fn.tabpagenr())
        end)

        it("creates a new tab after the active one when prompt returns { new = 'after' }", function()
            tabprompt.prompt_for_tab = function() return { new = "after" } end

            tabs.open_in_picked_tab(function() end)

            assert.are.equal(4, vim.fn.tabpagenr("$"))
            assert.are.equal(3, vim.fn.tabpagenr())
        end)

        it("creates a new tab before the active one when prompt returns { new = 'before' }", function()
            tabprompt.prompt_for_tab = function() return { new = "before" } end

            tabs.open_in_picked_tab(function() end)

            assert.are.equal(4, vim.fn.tabpagenr("$"))
            assert.are.equal(2, vim.fn.tabpagenr())
        end)

        it("navigates to an existing tab when prompt returns { tabnr = n }", function()
            tabprompt.prompt_for_tab = function() return { tabnr = 3 } end

            tabs.open_in_picked_tab(function() end)

            assert.are.equal(3, vim.fn.tabpagenr("$"))
            assert.are.equal(3, vim.fn.tabpagenr())
        end)

        it("does nothing when prompt returns nil (cancelled)", function()
            tabprompt.prompt_for_tab = function() return nil end

            tabs.open_in_picked_tab(function() end)

            assert.are.equal(3, vim.fn.tabpagenr("$"))
            assert.are.equal(2, vim.fn.tabpagenr())
        end)

        it("runs the action in the resulting tab context", function()
            tabprompt.prompt_for_tab = function() return { new = "after" } end

            local called = false
            tabs.open_in_picked_tab(function()
                called = true
                assert.are.equal(3, vim.fn.tabpagenr())
            end)

            assert.is_true(called)
        end)

        it("positions 'end' tab correctly even when original tab is at the end", function()
            vim.cmd("tabnext 3")
            tabprompt.prompt_for_tab = function() return { new = "end" } end

            tabs.open_in_picked_tab(function() end)

            assert.are.equal(4, vim.fn.tabpagenr("$"))
            assert.are.equal(4, vim.fn.tabpagenr())
        end)

        it("positions 'before' tab correctly when original tab is the first", function()
            vim.cmd("tabnext 1")
            tabprompt.prompt_for_tab = function() return { new = "before" } end

            tabs.open_in_picked_tab(function() end)

            assert.are.equal(4, vim.fn.tabpagenr("$"))
            assert.are.equal(1, vim.fn.tabpagenr())
        end)

        it("positions 'after' tab correctly when original tab is the last", function()
            vim.cmd("tabnext 3")
            tabprompt.prompt_for_tab = function() return { new = "after" } end

            tabs.open_in_picked_tab(function() end)

            assert.are.equal(4, vim.fn.tabpagenr("$"))
            assert.are.equal(4, vim.fn.tabpagenr())
        end)
    end)

    describe("prompt_switch_tab", function()
        local saved_prompt

        before_each(function()
            saved_prompt = tabprompt.prompt_for_tab
            -- Ensure we have exactly 3 tabs, on tab 2
            while vim.fn.tabpagenr("$") < 3 do
                vim.cmd("tabnew")
            end
            while vim.fn.tabpagenr("$") > 3 do
                vim.cmd("tabclose 4")
            end
            vim.cmd("tabnext 2")
            assert.are.equal(3, vim.fn.tabpagenr("$"))
            assert.are.equal(2, vim.fn.tabpagenr())
        end)

        after_each(function() tabprompt.prompt_for_tab = saved_prompt end)

        it("switches to the tab number returned by the prompt", function()
            tabprompt.prompt_for_tab = function() return { tabnr = 3 } end

            tabs.prompt_switch_tab()

            assert.are.equal(3, vim.fn.tabpagenr())
        end)

        it("switches to tab 1 when prompt returns tabnr 1", function()
            tabprompt.prompt_for_tab = function() return { tabnr = 1 } end

            tabs.prompt_switch_tab()

            assert.are.equal(1, vim.fn.tabpagenr())
        end)

        it("does nothing when prompt returns nil (cancelled)", function()
            tabprompt.prompt_for_tab = function() return nil end

            tabs.prompt_switch_tab()

            assert.are.equal(2, vim.fn.tabpagenr())
        end)

        it("does nothing for non-tabnr results", function()
            tabprompt.prompt_for_tab = function() return { new = "end" } end

            tabs.prompt_switch_tab()

            assert.are.equal(2, vim.fn.tabpagenr())
        end)
    end)

    describe("TabNew cwd behavior", function()
        local saved_dir

        before_each(function()
            saved_dir = vim.fn.getcwd()
        end)

        after_each(function()
            if saved_dir then
                vim.fn.chdir(saved_dir)
            end
        end)

        it("new tab inherits global cwd, not parent tab's :tcd", function()
            -- Use /usr (not a symlink on macOS) so getcwd() returns a
            -- predictable value.
            vim.cmd("cd /usr")
            local global_after_cd = vim.fn.getcwd()

            -- Create a second tab and go back to the first, so that :tcd
            -- applies tab-locally (with a single tab it elevates to global).
            -- NOTE: getcwd(-1) is not a reliable oracle for the global cwd
            -- once :tcd is in play (it can return the tab-local value), so
            -- only the effective cwd getcwd() is asserted below.
            vim.cmd("tabnew")
            vim.cmd("tabprev")

            -- Now set a tab-local directory that differs from global.
            vim.cmd("tcd /")
            assert.are.equal("/", vim.fn.getcwd())

            -- Open yet another new tab; it lands in the new tab.
            vim.cmd("tabnew")

            -- The new tab should use the global cwd, not the parent tab's :tcd.
            assert.are.equal(global_after_cd, vim.fn.getcwd())
        end)

        it("new tab in open_in_picked_tab inherits global cwd", function()
            local saved_prompt = tabprompt.prompt_for_tab
            tabprompt.prompt_for_tab = function() return { new = "end" } end

            vim.cmd("cd /usr")
            local global_after_cd = vim.fn.getcwd()

            -- Second tab so :tcd is genuinely tab-local.
            vim.cmd("tabnew")
            vim.cmd("tabprev")

            vim.cmd("tcd /")
            assert.are.equal("/", vim.fn.getcwd())

            tabs.open_in_picked_tab(function() end)

            assert.are.equal(global_after_cd, vim.fn.getcwd())

            tabprompt.prompt_for_tab = saved_prompt
        end)

        it("appends a Greek marker to tabs whose cwd differs from the global cwd", function()
            vim.cmd("cd /usr")
            local global_after_cd = vim.fn.getcwd()
            assert.are.equal(global_after_cd, tabs.get_global_cwd())

            -- Tab 2 gets its own working directory; tab 1 stays on global.
            vim.cmd("tabnew")
            vim.cmd("tcd /")

            -- Parse each tab's label: strip statusline control sequences
            -- (highlight groups and click handlers), collapse the escaped
            -- literal "%%" to "%", then capture the text after the "<nr> "
            -- prefix.
            local function tab_labels()
                local clean = tabs.tabline()
                    :gsub("%%#.-#", "")   -- highlight groups
                    :gsub("%%%d+T", "")   -- click-handler start
                    :gsub("%%T", "")      -- click-handler end
                    :gsub("%%%%", "%%")   -- escaped literal '%' marker -> '%'
                local labels = {}
                for seg in clean:gmatch("[^|]+") do
                    local nr, label = seg:match("^%s*(%d+)%s+(.-)%s*$")
                    if nr then
                        labels[tonumber(nr)] = label
                    end
                end
                return labels
            end

            local labels = tab_labels()
            -- Tab 2 (with :tcd) shows a trailing marker; tab 1 does not.
            assert.are.equal("[No Name]", labels[1])
            assert.are.equal("[No Name]α", labels[2])
        end)

        it("looks up registered cwd groups by key", function()
            vim.cmd("cd /usr")
            assert.is_nil(tabs.cwd_for_group_key("A"))

            vim.cmd("tabnew")
            vim.cmd("tcd /")
            assert.are.equal(vim.fs.normalize("/"), tabs.cwd_for_group_key("A"))

            vim.cmd("tabnew")
            vim.cmd("tcd /var")
            local beta_cwd = vim.fs.normalize(vim.fn.getcwd())
            assert.are.equal(vim.fs.normalize("/"), tabs.cwd_for_group_key("A"))
            assert.are.equal(beta_cwd, tabs.cwd_for_group_key("B"))
            assert.is_nil(tabs.cwd_for_group_key("K"))
        end)

        it("switch_cwd_group tcd's the current tab to a registered group", function()
            vim.cmd("cd /usr")
            assert.are.equal("/usr", vim.fn.getcwd())

            -- Register group A by giving a second tab a tab-local cwd.
            vim.cmd("tabnew")
            vim.cmd("tcd /")
            vim.cmd("tabprev")

            -- Current tab is back on the global cwd; switch it to group A.
            assert.are.equal("/usr", vim.fn.getcwd())
            assert.is_true(tabs.switch_cwd_group("A"))
            assert.are.equal("/", vim.fn.getcwd())
        end)

        it("switch_cwd_group returns false for an unregistered key", function()
            vim.cmd("cd /usr")
            local before = vim.fn.getcwd()
            assert.is_false(tabs.switch_cwd_group("A"))
            assert.are.equal(before, vim.fn.getcwd())
        end)

        it("switch_cwd_group error messages use the Greek letter", function()
            local saved_print = print
            local captured = {}
            print = function(...)
                local parts = {}
                for i = 1, select("#", ...) do
                    parts[i] = tostring(select(i, ...))
                end
                captured[#captured + 1] = table.concat(parts, "\t")
            end

            local ok = tabs.switch_cwd_group("A")
            print = saved_print

            assert.is_false(ok)
            assert.are.equal(1, #captured)
            assert.are.equal("No group α", captured[1])
        end)

        it("greek_for_key maps Latin keys to Greek letters", function()
            assert.are.equal("α", tabs.greek_for_key("A"))
            assert.are.equal("β", tabs.greek_for_key("B"))
            assert.are.equal("γ", tabs.greek_for_key("G"))
            -- Unknown keys fall back to the key itself.
            assert.are.equal("X", tabs.greek_for_key("X"))
        end)

        it("switch_to_global_cwd resets a tab-local cwd to the global cwd", function()
            vim.cmd("cd /usr")
            local global = vim.fn.getcwd()

            -- Give the current tab a tab-local cwd via a second tab.
            vim.cmd("tabnew")
            vim.cmd("tcd /")
            assert.are.equal("/", vim.fn.getcwd())

            tabs.switch_to_global_cwd()
            assert.are.equal(global, vim.fn.getcwd())
        end)

        it("switch_cwd_group returns false for a missing directory", function()
            local tmpdir = vim.fn.tempname()
            vim.fn.mkdir(tmpdir)

            -- Global cwd is /usr, distinct from tmpdir, so a second tab can
            -- register tmpdir as group A via a tab-local :tcd.
            vim.cmd("cd /usr")
            vim.cmd("tabnew")
            vim.cmd("tcd " .. vim.fn.fnameescape(tmpdir))
            vim.cmd("tabprev")
            vim.fn.delete(tmpdir, "rf")

            local before = vim.fn.getcwd()
            assert.is_false(tabs.switch_cwd_group("A"))
            assert.are.equal(before, vim.fn.getcwd())
        end)

        it("twd_statusline shows the cwd, '%'-marked only when it differs", function()
            vim.cmd("cd /usr")

            -- No :tcd here, so the cwd equals the global cwd: no '%'.
            local same = tabs.twd_statusline(30)
            assert.are.equal("/usr", same)

            -- Give the current tab its own working directory.
            vim.cmd("tabnew")
            vim.cmd("tcd /")
            local diff = tabs.twd_statusline(30)
            assert.are.equal("/%", diff)
        end)

        it("cloning a tab preserves its tab-local cwd and buffer identity", function()
            -- Create a real file in a temporary directory.  We use a real file
            -- because the bug only shows up when tabnew re-resolves a relative
            -- buffer name against the new tab's (global) cwd.
            local tmpfile = vim.fn.tempname()
            local tmpdir = vim.fn.fnamemodify(tmpfile, ":h")
            local relpath = "tab_clone_relpath"
            vim.fn.writefile({ "clone test" }, tmpdir .. "/" .. relpath)

            -- Global cwd becomes tmpdir; open the file by relative name.
            vim.cmd("cd " .. vim.fn.fnameescape(tmpdir))
            vim.cmd("edit " .. vim.fn.fnameescape(relpath))
            local source_buf = vim.api.nvim_get_current_buf()
            -- Use whatever absolute path Neovim resolved the buffer to (e.g.
            -- /var -> /private/var) so our assertions are not brittle to symlinks.
            local abspath = vim.api.nvim_buf_get_name(0)

            -- Need a second tab so the subsequent :tcd is truly tab-local.
            vim.cmd("tabnew")
            vim.cmd("tabprev")

            -- Set a tab-local directory that differs from global cwd.
            vim.cmd("tcd /")
            assert.are.equal("/", vim.fn.getcwd())
            -- Buffer name stays absolute even after :tcd.
            assert.are.equal(abspath, vim.api.nvim_buf_get_name(0))

            -- Clone the current tab (the action bound to <leader>tt).
            tabs._open_current_buffer_in_new_tab(false)

            -- Cleanup the temporary file regardless of assertions.
            pcall(os.remove, abspath)

            -- We should be in the newly created tab.
            assert.are.equal(3, vim.fn.tabpagenr("$"))

            -- The clone must keep the source tab's tab-local working directory.
            assert.are.equal("/", vim.fn.getcwd())

            -- The clone must reuse the original buffer, not create a duplicate
            -- resolved against the global cwd.
            assert.are.equal(source_buf, vim.api.nvim_get_current_buf())
            assert.are.equal(abspath, vim.api.nvim_buf_get_name(0))
        end)

        it("truncate_path elides the head of long paths", function()
            assert.are.equal("short", tabs.truncate_path("short", 30))
            local long = "/a/very/long/path/that/exceeds"
            local out = tabs.truncate_path(long, 15)
            assert.are.equal(15, #out)
            assert.are.equal("...", out:sub(1, 3))
            assert.truthy(long:find(out:sub(4), 1, true),
                "Expected truncated tail to be a suffix of the original, got: " .. out)
        end)
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
