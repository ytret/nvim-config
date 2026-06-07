local tabprompt = require("ytret.tabprompt")

describe("prompt_for_tab", function()
    local saved_getchar, saved_input, saved_nr2char, saved_cmdheight, saved_print

    before_each(function()
        saved_getchar = tabprompt._getchar
        saved_input = tabprompt._input
        saved_nr2char = tabprompt._nr2char
        saved_cmdheight = tabprompt._cmdheight
        saved_print = tabprompt._print
    end)

    after_each(function()
        tabprompt._getchar = saved_getchar
        tabprompt._input = saved_input
        tabprompt._nr2char = saved_nr2char
        tabprompt._cmdheight = saved_cmdheight
        tabprompt._print = saved_print
    end)

    describe("with <= 9 tabs (getchar path)", function()
        it("returns tabnr when a valid digit is pressed", function()
            tabprompt._getchar = function() return 50 end
            tabprompt._nr2char = function(c) return string.char(c) end
            tabprompt._cmdheight = function() return 1 end
            tabprompt._print = function() end
            local result = tabprompt.prompt_for_tab({ last_tabnr = 5 })
            assert.same({ tabnr = 2 }, result)
        end)

        it("returns nil on escape (27)", function()
            tabprompt._getchar = function() return 27 end
            tabprompt._nr2char = function(c) return string.char(c) end
            tabprompt._cmdheight = function() return 1 end
            tabprompt._print = function() end
            assert.is_nil(tabprompt.prompt_for_tab({ last_tabnr = 5 }))
        end)

        it("returns nil on Ctrl-C (3)", function()
            tabprompt._getchar = function() return 3 end
            tabprompt._nr2char = function(c) return string.char(c) end
            tabprompt._cmdheight = function() return 1 end
            tabprompt._print = function() end
            assert.is_nil(tabprompt.prompt_for_tab({ last_tabnr = 5 }))
        end)

        it("returns nil when getchar errors", function()
            tabprompt._getchar = function() error("fail") end
            tabprompt._cmdheight = function() return 1 end
            tabprompt._print = function() end
            assert.is_nil(tabprompt.prompt_for_tab({ last_tabnr = 5 }))
        end)

        it("returns nil when getchar returns non-number", function()
            tabprompt._getchar = function() return "abc" end
            tabprompt._cmdheight = function() return 1 end
            tabprompt._print = function() end
            assert.is_nil(tabprompt.prompt_for_tab({ last_tabnr = 5 }))
        end)

        it("returns { new = 'end' } when 'N' is pressed", function()
            tabprompt._getchar = function() return 78 end
            tabprompt._nr2char = function(c) return string.char(c) end
            tabprompt._cmdheight = function() return 1 end
            tabprompt._print = function() end
            local result = tabprompt.prompt_for_tab({ last_tabnr = 5, allow_new = true })
            assert.same({ new = "end" }, result)
        end)

        it("returns { new = 'end' } for lowercase 'n'", function()
            tabprompt._getchar = function() return 110 end
            tabprompt._nr2char = function(c) return string.char(c) end
            tabprompt._cmdheight = function() return 1 end
            tabprompt._print = function() end
            local result = tabprompt.prompt_for_tab({ last_tabnr = 5, allow_new = true })
            assert.same({ new = "end" }, result)
        end)

        it("returns { new = 'after' } when 'A' is pressed", function()
            tabprompt._getchar = function() return 65 end
            tabprompt._nr2char = function(c) return string.char(c) end
            tabprompt._cmdheight = function() return 1 end
            tabprompt._print = function() end
            local result = tabprompt.prompt_for_tab({ last_tabnr = 5, allow_new = true })
            assert.same({ new = "after" }, result)
        end)

        it("returns { new = 'before' } when 'B' is pressed", function()
            tabprompt._getchar = function() return 66 end
            tabprompt._nr2char = function(c) return string.char(c) end
            tabprompt._cmdheight = function() return 1 end
            tabprompt._print = function() end
            local result = tabprompt.prompt_for_tab({ last_tabnr = 5, allow_new = true })
            assert.same({ new = "before" }, result)
        end)

        it("skips print when cmdheight is 0", function()
            tabprompt._getchar = function() return 50 end
            tabprompt._nr2char = function(c) return string.char(c) end
            tabprompt._cmdheight = function() return 0 end
            local printed = false
            tabprompt._print = function() printed = true end
            tabprompt.prompt_for_tab({ last_tabnr = 3 })
            assert.is_false(printed)
        end)

        it("retries on invalid input", function()
            local calls = { 63, 50 }
            tabprompt._getchar = function()
                local v = table.remove(calls, 1)
                return v
            end
            tabprompt._nr2char = function(c) return string.char(c) end
            tabprompt._cmdheight = function() return 1 end
            tabprompt._print = function() end
            local result = tabprompt.prompt_for_tab({ last_tabnr = 5 })
            assert.same({ tabnr = 2 }, result)
        end)
    end)

    describe("with > 9 tabs (input path)", function()
        it("returns tabnr for valid numeric input", function()
            tabprompt._input = function(_) return "12" end
            local result = tabprompt.prompt_for_tab({ last_tabnr = 15 })
            assert.same({ tabnr = 12 }, result)
        end)

        it("returns nil when input is cancelled (empty)", function()
            tabprompt._input = function(_) return "" end
            assert.is_nil(tabprompt.prompt_for_tab({ last_tabnr = 15 }))
        end)

        it("returns nil when input errors", function()
            tabprompt._input = function() error("fail") end
            assert.is_nil(tabprompt.prompt_for_tab({ last_tabnr = 15 }))
        end)

        it("returns nil for out-of-range tab number", function()
            tabprompt._input = function(_) return "20" end
            local invalid_called = false
            local result = tabprompt.prompt_for_tab({
                last_tabnr = 15,
                on_invalid = function() invalid_called = true end,
            })
            assert.is_nil(result)
            assert.is_true(invalid_called)
        end)

        it("returns nil for tab number < 1", function()
            tabprompt._input = function(_) return "0" end
            assert.is_nil(tabprompt.prompt_for_tab({ last_tabnr = 15 }))
        end)

        it("returns nil for non-numeric input", function()
            tabprompt._input = function(_) return "abc" end
            assert.is_nil(tabprompt.prompt_for_tab({ last_tabnr = 15 }))
        end)

        it("returns { new = 'end' } for 'N' input", function()
            tabprompt._input = function(_) return "N" end
            local result = tabprompt.prompt_for_tab({ last_tabnr = 15, allow_new = true })
            assert.same({ new = "end" }, result)
        end)

        it("returns { new = 'end' } for lowercase 'n' input", function()
            tabprompt._input = function(_) return "n" end
            local result = tabprompt.prompt_for_tab({ last_tabnr = 15, allow_new = true })
            assert.same({ new = "end" }, result)
        end)

        it("returns { new = 'after' } for 'A' input", function()
            tabprompt._input = function(_) return "A" end
            local result = tabprompt.prompt_for_tab({ last_tabnr = 15, allow_new = true })
            assert.same({ new = "after" }, result)
        end)

        it("returns { new = 'before' } for 'B' input", function()
            tabprompt._input = function(_) return "B" end
            local result = tabprompt.prompt_for_tab({ last_tabnr = 15, allow_new = true })
            assert.same({ new = "before" }, result)
        end)
    end)

    describe("default last_tabnr", function()
        it("uses vim.fn.tabpagenr when no last_tabnr provided", function()
            tabprompt._getchar = function() return 49 end
            tabprompt._nr2char = function(c) return string.char(c) end
            tabprompt._cmdheight = function() return 0 end
            tabprompt._print = function() end
            local result = tabprompt.prompt_for_tab()
            assert.same({ tabnr = 1 }, result)
        end)
    end)
end)

