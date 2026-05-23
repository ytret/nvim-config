local wp = require("yt-window-picker")

describe("index_to_label", function()
    it("converts 1 to A", function()
        assert.equals("A", wp.index_to_label(1))
    end)

    it("converts 2 to B", function()
        assert.equals("B", wp.index_to_label(2))
    end)

    it("converts 26 to Z", function()
        assert.equals("Z", wp.index_to_label(26))
    end)

    it("converts 27 to AA", function()
        assert.equals("AA", wp.index_to_label(27))
    end)

    it("converts 28 to AB", function()
        assert.equals("AB", wp.index_to_label(28))
    end)

    it("converts 52 to AZ", function()
        assert.equals("AZ", wp.index_to_label(52))
    end)

    it("converts 53 to BA", function()
        assert.equals("BA", wp.index_to_label(53))
    end)

    it("handles 703 (AAA)", function()
        assert.equals("AAA", wp.index_to_label(703))
    end)
end)
