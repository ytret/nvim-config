local tabs = require("ytret.tabs")

local function make_tabs(labels)
    local result = {}
    for i, label in ipairs(labels) do
        result[i] = {
            label = label,
            w = 1 + #tostring(i) + 1 + #label + 1,
        }
    end
    return result
end

describe("_scrolled_range", function()
    it("returns all tabs when total width fits within columns", function()
        local t = make_tabs({ "alpha", "bravo" })
        -- total_w: (1+1+1+5+1)=9 + 1 + (1+1+1+5+1)=9 = 19
        local range = tabs._scrolled_range(t, 2, 1, 999)
        assert.are.same({ start = 1, end_ = 2, left_arrow = false, right_arrow = false }, range)
    end)

    it("returns false for both arrows when all tabs fit", function()
        local t = make_tabs({ "a", "b", "c" })
        local range = tabs._scrolled_range(t, 3, 2, 999)
        assert.False(range.left_arrow)
        assert.False(range.right_arrow)
    end)

    it("includes active tab and shows arrows when tabline exceeds columns", function()
        local t = make_tabs({ "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" })
        -- 10 tabs, cur=5, cols=40
        local range = tabs._scrolled_range(t, 10, 5, 40)
        assert.is_true(range.start <= 5)
        assert.is_true(range.end_ >= 5)
        assert.is_true(range.left_arrow or range.right_arrow)
    end)

    it("shows active tab when at far left extreme", function()
        local t = make_tabs({ "first", "b", "c", "d", "e", "f", "g", "h" })
        -- 8 tabs, cur=1, cols=30
        local range = tabs._scrolled_range(t, 8, 1, 30)
        assert.equal(1, range.start)
        assert.is_true(range.end_ > range.start)
        assert.False(range.left_arrow)
    end)

    it("shows active tab when at far right extreme", function()
        local t = make_tabs({ "a", "b", "c", "d", "e", "f", "g", "lastone" })
        -- 8 tabs, cur=8, cols=30
        local range = tabs._scrolled_range(t, 8, 8, 30)
        assert.equal(8, range.end_)
        assert.is_true(range.start < range.end_)
        assert.False(range.right_arrow)
    end)

    it("shows single tab without arrows when only one tab exists", function()
        local t = make_tabs({ "alone" })
        local range = tabs._scrolled_range(t, 1, 1, 999)
        assert.are.same({ start = 1, end_ = 1, left_arrow = false, right_arrow = false }, range)
    end)

    it("shows only right arrow when leftmost tabs start in view", function()
        local t = make_tabs({ "a", "b", "c", "d", "e", "f", "g", "h" })
        -- 8 tabs, cur=1, cols=45
        local range = tabs._scrolled_range(t, 8, 1, 45)
        assert.equal(1, range.start)
        assert.False(range.left_arrow)
        assert.True(range.right_arrow)
    end)

    it("shows only left arrow when rightmost tabs are in view", function()
        local t = make_tabs({ "a", "b", "c", "d", "e", "f", "g", "h" })
        -- 8 tabs, cur=8, cols=45
        local range = tabs._scrolled_range(t, 8, 8, 45)
        assert.equal(8, range.end_)
        assert.False(range.right_arrow)
        assert.True(range.left_arrow)
    end)

    it("renders fewer tabs than total when column width forces retraction", function()
        local t = make_tabs({
            "one", "two", "three", "four", "five", "six",
            "seven", "eight", "nine", "ten", "eleven", "twelve",
        })
        -- 12 tabs, cur=6, cols=25
        local range = tabs._scrolled_range(t, 12, 6, 25)
        local rendered = range.end_ - range.start + 1
        assert.is_true(rendered < 12,
            "Expected fewer tabs rendered than total, got " .. rendered .. " vs 12")
    end)

    it("handles zero tabs", function()
        local range = tabs._scrolled_range({}, 0, 1, 80)
        assert.are.same({ start = 1, end_ = 1, left_arrow = false, right_arrow = false }, range)
    end)

    it("returns left and right arrows when both sides are clipped", function()
        local t = make_tabs({ "aa", "bb", "cc", "dd", "ee", "ff", "gg", "hh", "ii", "jj", "kk", "ll", "mm", "nn", "oo" })
        -- 15 tabs, cur=8, cols=40
        local range = tabs._scrolled_range(t, 15, 8, 40)
        assert.True(range.left_arrow)
        assert.True(range.right_arrow)
        assert.is_true(range.start <= 8)
        assert.is_true(range.end_ >= 8)
    end)
end)
