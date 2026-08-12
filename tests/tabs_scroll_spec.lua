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
        assert.are.same({ start = 1, end_ = 2, left_hidden = 0, right_hidden = 0 }, range)
    end)

    it("reports no hidden tabs when all tabs fit", function()
        local t = make_tabs({ "a", "b", "c" })
        local range = tabs._scrolled_range(t, 3, 2, 999)
        assert.equal(0, range.left_hidden)
        assert.equal(0, range.right_hidden)
    end)

    it("includes active tab and shows hidden tabs when tabline exceeds columns", function()
        local t = make_tabs({ "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" })
        -- 10 tabs, cur=5, cols=40
        local range = tabs._scrolled_range(t, 10, 5, 40)
        assert.is_true(range.start <= 5)
        assert.is_true(range.end_ >= 5)
        assert.is_true(range.left_hidden > 0 or range.right_hidden > 0)
    end)

    it("shows active tab when at far left extreme", function()
        local t = make_tabs({ "first", "b", "c", "d", "e", "f", "g", "h" })
        -- 8 tabs, cur=1, cols=30
        local range = tabs._scrolled_range(t, 8, 1, 30)
        assert.equal(1, range.start)
        assert.is_true(range.end_ > range.start)
        assert.equal(0, range.left_hidden)
        assert.equal(8 - range.end_, range.right_hidden)
    end)

    it("shows active tab when at far right extreme", function()
        local t = make_tabs({ "a", "b", "c", "d", "e", "f", "g", "lastone" })
        -- 8 tabs, cur=8, cols=30
        local range = tabs._scrolled_range(t, 8, 8, 30)
        assert.equal(8, range.end_)
        assert.is_true(range.start < range.end_)
        assert.equal(range.start - 1, range.left_hidden)
        assert.equal(0, range.right_hidden)
    end)

    it("shows single tab without hidden tabs when only one tab exists", function()
        local t = make_tabs({ "alone" })
        local range = tabs._scrolled_range(t, 1, 1, 999)
        assert.are.same({ start = 1, end_ = 1, left_hidden = 0, right_hidden = 0 }, range)
    end)

    it("shows only right hidden count when leftmost tabs start in view", function()
        local t = make_tabs({ "a", "b", "c", "d", "e", "f", "g", "h" })
        -- 8 tabs, cur=1, cols=45
        local range = tabs._scrolled_range(t, 8, 1, 45)
        assert.equal(1, range.start)
        assert.equal(0, range.left_hidden)
        assert.True(range.right_hidden > 0)
    end)

    it("shows only left hidden count when rightmost tabs are in view", function()
        local t = make_tabs({ "a", "b", "c", "d", "e", "f", "g", "h" })
        -- 8 tabs, cur=8, cols=45
        local range = tabs._scrolled_range(t, 8, 8, 45)
        assert.equal(8, range.end_)
        assert.True(range.left_hidden > 0)
        assert.equal(0, range.right_hidden)
    end)

    it("renders fewer tabs than total when column width forces retraction", function()
        local t = make_tabs({
            "one",
            "two",
            "three",
            "four",
            "five",
            "six",
            "seven",
            "eight",
            "nine",
            "ten",
            "eleven",
            "twelve",
        })
        -- 12 tabs, cur=6, cols=25
        local range = tabs._scrolled_range(t, 12, 6, 25)
        local rendered = range.end_ - range.start + 1
        assert.is_true(
            rendered < 12,
            "Expected fewer tabs rendered than total, got " .. rendered .. " vs 12"
        )
        assert.equal(range.start - 1, range.left_hidden)
        assert.equal(12 - range.end_, range.right_hidden)
    end)

    it("handles zero tabs", function()
        local range = tabs._scrolled_range({}, 0, 1, 80)
        assert.are.same({ start = 1, end_ = 1, left_hidden = 0, right_hidden = 0 }, range)
    end)

    it("returns hidden counts on both sides when both sides are clipped", function()
        local t = make_tabs({
            "aa",
            "bb",
            "cc",
            "dd",
            "ee",
            "ff",
            "gg",
            "hh",
            "ii",
            "jj",
            "kk",
            "ll",
            "mm",
            "nn",
            "oo",
        })
        -- 15 tabs, cur=8, cols=40
        local range = tabs._scrolled_range(t, 15, 8, 40)
        assert.True(range.left_hidden > 0)
        assert.True(range.right_hidden > 0)
        assert.is_true(range.start <= 8)
        assert.is_true(range.end_ >= 8)
        assert.equal(range.start - 1, range.left_hidden)
        assert.equal(15 - range.end_, range.right_hidden)
    end)

    it("hidden counts are consistent with the visible range", function()
        local t =
            make_tabs({ "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" })
        local range = tabs._scrolled_range(t, 9, 5, 20)
        assert.equal(range.start - 1, range.left_hidden)
        assert.equal(9 - range.end_, range.right_hidden)
    end)
end)

describe("_hidden_indicator", function()
    it("returns empty string when there are no hidden tabs", function()
        assert.are.equal("", tabs._hidden_indicator(0, "left"))
        assert.are.equal("", tabs._hidden_indicator(0, "right"))
        assert.are.equal("", tabs._hidden_indicator(-1, "left"))
    end)

    it(
        "renders a left indicator with count",
        function() assert.are.equal("<5", tabs._hidden_indicator(5, "left")) end
    )

    it(
        "renders a right indicator with count",
        function() assert.are.equal("7>", tabs._hidden_indicator(7, "right")) end
    )

    it("handles multi-digit counts", function()
        assert.are.equal("<12", tabs._hidden_indicator(12, "left"))
        assert.are.equal("99>", tabs._hidden_indicator(99, "right"))
    end)
end)
