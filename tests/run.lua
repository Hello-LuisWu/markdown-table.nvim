vim = vim
vim.opt.rtp:prepend(vim.fn.getcwd())
local parser = require("markdown_table.parser")
local formatter = require("markdown_table.formatter")

local function assert_equal(actual, expected, label)
	if actual ~= expected then
		error((label or "assertion") .. " failed\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(actual))
	end
end

local tsv = "Name\tEvent\tDescription\n启动\tVimEnter\t启动完成\n文件\tBufReadPost\t读取文件"
local rows = assert(parser.parse(tsv, "tsv"))
assert_equal(#rows, 3, "TSV row count")
assert_equal(rows[2][1], "启动", "TSV unicode cell")

local html = '<table><tr><th>Name</th><th>Value</th></tr><tr><td>A &amp; B</td><td><b>42</b></td></tr></table>'
local html_rows = assert(parser.parse(html, "html"))
assert_equal(html_rows[2][1], "A & B", "HTML entity")
assert_equal(html_rows[2][2], "42", "HTML nested tag")

local csv = 'Name,Note\n"A, B","say ""hello"""'
local csv_rows = assert(parser.parse(csv, "csv"))
assert_equal(csv_rows[2][1], "A, B", "CSV quoted comma")
assert_equal(csv_rows[2][2], 'say "hello"', "CSV escaped quote")

local formatted = assert(formatter.format({ { "名称", "事件" }, { "启动", "VimEnter" } }))
assert_equal(formatted[2]:sub(1, 2), "| ", "Markdown separator")
print("markdown-table.nvim: all tests passed")
