describe("autotheme", function()
    local home, theme_file, schemes, warnings, restore_fns
    local original_background, original_highlight

    local function pause(ms)
        vim.wait(ms, function() return false end, 10)
    end

    local function write_theme(theme)
        local file = assert(io.open(theme_file, "w"))
        file:write(theme)
        file:close()
    end

    local function load_plugin()
        local original = os.getenv
        os.getenv = function(name)
            if name == "HOME" then
                return home
            end
            return original(name)
        end
        local ok, err = pcall(dofile, "plugin/autotheme.lua")
        os.getenv = original
        assert.is_true(ok, tostring(err))
    end

    local function expect_background(background)
        assert.is_true(
            vim.wait(1500, function() return vim.o.background == background end, 10),
            "background did not become " .. background
        )
    end

    local function count_reads()
        local original = io.open
        local count = 0
        io.open = function(path, mode)
            if path == theme_file and mode == "r" then
                count = count + 1
            end
            return original(path, mode)
        end
        table.insert(restore_fns, function() io.open = original end)
        return function() return count end
    end

    before_each(function()
        if _G.ytret_autotheme_stop then
            _G.ytret_autotheme_stop()
        end
        original_background = vim.o.background
        original_highlight = YTRET_HIGHLIGHT
        YTRET_HIGHLIGHT = nil
        home = vim.fn.tempname()
        theme_file = home .. "/.config/ytret/theme.txt"
        vim.fn.mkdir(vim.fn.fnamemodify(theme_file, ":h"), "p")
        schemes, warnings, restore_fns = {}, {}, {}
        local original_colorscheme = vim.cmd.colorscheme
        vim.cmd.colorscheme = function(name) table.insert(schemes, name) end
        table.insert(restore_fns, function() vim.cmd.colorscheme = original_colorscheme end)
        local original_notify = vim.notify
        vim.notify = function(message, level)
            if message:sub(1, 11) == "autotheme: " then
                table.insert(warnings, { message = message, level = level })
            else
                original_notify(message, level)
            end
        end
        table.insert(restore_fns, function() vim.notify = original_notify end)
        for _, name in ipairs({ "TabLine", "TabLineSel", "TabLineFill", "MyTrailingWhitespace" }) do
            local hl = vim.api.nvim_get_hl(0, { name = name })
            table.insert(restore_fns, function() vim.api.nvim_set_hl(0, name, hl) end)
        end
        vim.api.nvim_set_hl(0, "MyTrailingWhitespace", {})
    end)

    after_each(function()
        if _G.ytret_autotheme_stop then
            _G.ytret_autotheme_stop()
        end
        for i = #restore_fns, 1, -1 do
            restore_fns[i]()
        end
        pcall(vim.api.nvim_del_augroup_by_name, "YtretTrailingWhitespace")
        vim.cmd("match none")
        YTRET_HIGHLIGHT = original_highlight
        vim.o.background = original_background
        vim.fn.delete(home, "rf")
    end)

    it("applies light at startup and sets the tabline highlights", function()
        write_theme("light\n")
        load_plugin()
        assert.equals("light", vim.o.background)
        assert.same({ "modus_operandi" }, schemes)
        assert.equals(0xd0d0d0, vim.api.nvim_get_hl(0, { name = "TabLine" }).bg)
        assert.equals(0xffffff, vim.api.nvim_get_hl(0, { name = "TabLineSel" }).bg)
        assert.equals(0xe8e8e8, vim.api.nvim_get_hl(0, { name = "TabLineFill" }).bg)
    end)

    it("applies dark at startup", function()
        write_theme("dark\n")
        load_plugin()
        assert.equals("dark", vim.o.background)
        assert.same({ "modus_vivendi" }, schemes)
    end)

    it("preserves optional trailing whitespace highlights", function()
        write_theme("dark\n")
        load_plugin()
        assert.same({}, vim.api.nvim_get_hl(0, { name = "MyTrailingWhitespace" }))
        YTRET_HIGHLIGHT = true
        load_plugin()
        assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "MyTrailingWhitespace" }).bg)
    end)

    it("recovers from a pause between truncation and writing", function()
        write_theme("light\n")
        load_plugin()
        local file = assert(io.open(theme_file, "w"))
        pause(120)
        assert.equals("light", vim.o.background)
        assert.equals(0, #warnings, vim.inspect(warnings))
        file:write("dark\n")
        file:close()
        expect_background("dark")
        write_theme("light\n")
        expect_background("light")
    end)

    it("debounces a burst of writes and skips an unchanged theme", function()
        write_theme("dark\n")
        load_plugin()
        local reads = count_reads()
        for _ = 1, 30 do
            write_theme("light\n")
            write_theme("dark\n")
        end
        write_theme("light\n")
        expect_background("light")
        assert.equals(1, reads())
        assert.same({ "modus_vivendi", "modus_operandi" }, schemes)
        write_theme("light\n")
        pause(150)
        assert.equals(2, #schemes)
    end)

    it("keeps watching after atomic replacement", function()
        write_theme("dark\n")
        load_plugin()
        local replacement = theme_file .. ".new"
        vim.fn.writefile({ "light" }, replacement)
        assert(vim.uv.fs_rename(replacement, theme_file))
        expect_background("light")
        write_theme("dark\n")
        expect_background("dark")
    end)

    it("recovers when a missing file is recreated", function()
        write_theme("light\n")
        load_plugin()
        assert(os.remove(theme_file))
        pause(120)
        assert.equals("light", vim.o.background)
        write_theme("dark\n")
        expect_background("dark")
    end)

    it("warns once for an invalid value without retrying and accepts a correction", function()
        write_theme("light\n")
        load_plugin()
        local reads = count_reads()
        write_theme("drak\n")
        pause(150)
        assert.equals("light", vim.o.background)
        assert.equals(1, #warnings)
        assert.matches('invalid theme "drak"', warnings[1].message, 1, true)
        assert.equals(vim.log.levels.WARN, warnings[1].level)
        assert.equals(1, reads())
        pause(300)
        assert.equals(1, reads())
        write_theme("drak\n")
        pause(150)
        assert.equals(1, #warnings)
        write_theme("dark\n")
        expect_background("dark")
        assert.equals(1, #warnings)
    end)

    it("bounds retries for an empty file and recovers after exhaustion", function()
        write_theme("light\n")
        load_plugin()
        local reads = count_reads()
        write_theme("")
        assert.is_true(vim.wait(1600, function() return #warnings == 1 end, 10))
        assert.equals("light", vim.o.background)
        assert.equals(6, reads())
        pause(300)
        assert.equals(6, reads())
        assert.equals(1, #warnings)
        write_theme("dark\n")
        expect_background("dark")
    end)

    it("bounds retries when the file is missing at startup", function()
        vim.o.background = "light"
        local reads = count_reads()
        load_plugin()
        assert.is_true(vim.wait(1600, function() return #warnings == 1 end, 10))
        assert.equals("light", vim.o.background)
        assert.equals(6, reads())
        pause(300)
        assert.equals(6, reads())
        write_theme("dark\n")
        expect_background("dark")
    end)

    it("retries unreadable files without changing the theme", function()
        write_theme("light\n")
        load_plugin()
        local original = io.open
        local blocked = true
        io.open = function(path, mode)
            if blocked and path == theme_file and mode == "r" then
                return nil, "Permission denied"
            end
            return original(path, mode)
        end
        table.insert(restore_fns, function() io.open = original end)
        write_theme("dark\n")
        pause(120)
        assert.equals("light", vim.o.background)
        blocked = false
        expect_background("dark")
        assert.equals(0, #warnings)
    end)

    it("ignores changes to other files in the directory", function()
        write_theme("light\n")
        load_plugin()
        local reads = count_reads()
        vim.fn.writefile({ "dark" }, theme_file .. ".other")
        pause(150)
        assert.equals(0, reads())
    end)

    it("cleans up the previous watcher and pending retries when sourced again", function()
        write_theme("light\n")
        load_plugin()
        write_theme("")
        pause(100)
        write_theme("light\n")
        load_plugin()
        schemes = {}
        local reads = count_reads()
        write_theme("dark\n")
        expect_background("dark")
        pause(300)
        assert.equals(1, reads())
        assert.same({ "modus_vivendi" }, schemes)
        assert.equals(0, #warnings)
    end)
end)
