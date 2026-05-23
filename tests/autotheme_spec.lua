describe("autotheme", function()
    local restore_fns = {}

    before_each(function()
        restore_fns = {}
        YTRET_HIGHLIGHT = nil
    end)

    after_each(function()
        for _, fn in ipairs(restore_fns) do
            pcall(fn)
        end
    end)

    local function mock_env(theme)
        local orig_io = io.lines
        local called = false
        io.lines = function()
            return function()
                if not called then
                    called = true
                    return theme
                end
                return nil
            end
        end
        table.insert(restore_fns, function() io.lines = orig_io end)

        local orig_fs = vim.loop.new_fs_event
        vim.loop.new_fs_event = function() return nil end
        table.insert(restore_fns, function() vim.loop.new_fs_event = orig_fs end)

        local orig_cs = vim.cmd.colorscheme
        vim.cmd.colorscheme = function() end
        table.insert(restore_fns, function() vim.cmd.colorscheme = orig_cs end)
    end

    describe("light mode", function()
        it("sets background to light", function()
            mock_env("light")
            dofile("plugin/autotheme.lua")
            assert.Equal("light", vim.o.background)
        end)
    end)

    describe("dark mode", function()
        it("sets background to dark", function()
            mock_env("dark")
            dofile("plugin/autotheme.lua")
            assert.Equal("dark", vim.o.background)
        end)
    end)

    describe("tabline highlights", function()
        it("sets TabLine, TabLineSel, TabLineFill highlight groups", function()
            mock_env("light")
            dofile("plugin/autotheme.lua")
            assert.Equal(1, vim.fn.hlexists("TabLine"))
            assert.Equal(1, vim.fn.hlexists("TabLineSel"))
            assert.Equal(1, vim.fn.hlexists("TabLineFill"))
        end)
    end)

    describe("trailing whitespace", function()
        it("does not set MyTrailingWhitespace when YTRET_HIGHLIGHT is nil", function()
            mock_env("dark")
            dofile("plugin/autotheme.lua")
            assert.Equal(0, vim.fn.hlexists("MyTrailingWhitespace"))
        end)

        it("sets MyTrailingWhitespace when YTRET_HIGHLIGHT is true", function()
            YTRET_HIGHLIGHT = true
            mock_env("dark")
            dofile("plugin/autotheme.lua")
            assert.Equal(1, vim.fn.hlexists("MyTrailingWhitespace"))
        end)
    end)
end)
