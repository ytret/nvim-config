require("ytret.remap")

local function feed(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
end

describe("backspace in replace mode", function()
    before_each(function() vim.api.nvim_buf_set_lines(0, 0, -1, false, { "abcd" }) end)

    it("insert mode still deletes a single char", function()
        vim.api.nvim_win_set_cursor(0, { 1, 2 })
        feed("i<BS><Esc>")
        assert.equals("acd", vim.api.nvim_get_current_line())
    end)

    it("replace mode restores replaced chars like vanilla <BS>", function()
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        feed("RX<BS><Esc>")
        assert.equals(
            "abcd",
            vim.api.nvim_get_current_line(),
            "expected replaced char restored, not deleted"
        )
        assert.equals(0, vim.api.nvim_win_get_cursor(0)[2])
    end)

    it("virtual replace mode restores replaced chars like vanilla <BS>", function()
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        feed("gRX<BS><Esc>")
        assert.equals(
            "abcd",
            vim.api.nvim_get_current_line(),
            "expected replaced char restored, not deleted"
        )
        assert.equals(0, vim.api.nvim_win_get_cursor(0)[2])
    end)
end)
