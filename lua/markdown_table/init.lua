local parser = require("markdown_table.parser")
local formatter = require("markdown_table.formatter")
local clipboard = require("markdown_table.clipboard")

local M = {}
local defaults = {
	mappings = {
		convert = "<leader>mt",
		html = "<leader>mh",
		format = "<leader>mf",
	},
	clipboard = { prefer_html = true },
	default_alignment = "left",
	min_column_width = 3,
	notify = true,
}
local config = vim.deepcopy(defaults)

local function notify(message, level)
	if config.notify then vim.notify("markdown-table: " .. message, level or vim.log.levels.INFO) end
end

local function render(text, format)
	local rows, align_or_error, detected = parser.parse(text, format)
	if not rows then return nil, align_or_error end
	local lines, err = formatter.format(rows, {
		align = align_or_error,
		default_alignment = config.default_alignment,
		min_column_width = config.min_column_width,
	})
	if not lines then return nil, err end
	return lines, detected
end

local function insert_lines(lines)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1
	local current = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
	if current == "" then
		-- 空白缓冲区直接替换空行，避免表格前多出一行空白。
		vim.api.nvim_buf_set_lines(0, row, row + 1, false, lines)
	else
		-- 非空行则在光标所在行下方插入表格。
		vim.api.nvim_buf_set_lines(0, row + 1, row + 1, false, lines)
	end
end

function M.convert(opts)
	opts = opts or {}
	local text, format = clipboard.get({
		format = opts.format,
		prefer_html = config.clipboard.prefer_html,
	})
	if not text then notify(format, vim.log.levels.WARN) return false end
	local lines, detected_or_error = render(text, format)
	if not lines then notify(detected_or_error, vim.log.levels.ERROR) return false end
	insert_lines(lines)
	notify("已转换 " .. tostring(detected_or_error) .. " 表格")
	return true
end

function M.convert_visual(opts)
	opts = opts or {}
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local start_row, end_row = start_pos[2], end_pos[2]
	local start_col, end_col = start_pos[3], end_pos[3]
	if start_row == 0 or end_row == 0 then notify("没有有效的 Visual 选区", vim.log.levels.WARN) return false end
	if start_row > end_row or (start_row == end_row and start_col > end_col) then
		start_row, end_row, start_col, end_col = end_row, start_row, end_col, start_col
	end
	local mode = vim.fn.visualmode()
	local buf = vim.api.nvim_get_current_buf()
	local text
	if mode == "V" or mode == "\22" then
		text = table.concat(vim.api.nvim_buf_get_lines(buf, start_row - 1, end_row, false), "\n")
	else
		local selected = vim.api.nvim_buf_get_text(buf, start_row - 1, start_col - 1, end_row - 1, end_col, {})
		text = table.concat(selected, "\n")
	end
	local lines, detected_or_error = render(text, opts.format or "auto")
	if not lines then notify(detected_or_error, vim.log.levels.ERROR) return false end
	if mode == "V" or mode == "\22" then
		vim.api.nvim_buf_set_lines(buf, start_row - 1, end_row, false, lines)
	else
		vim.api.nvim_buf_set_text(buf, start_row - 1, start_col - 1, end_row - 1, end_col, lines)
	end
	notify("选区已转换为 Markdown 表格（" .. tostring(detected_or_error) .. "）")
	return true
end

local function find_table_range()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local current = cursor[1] - 1
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local function is_table_line(line)
		return line:find("|", 1, true) ~= nil
	end
	if not lines[current + 1] or not is_table_line(lines[current + 1]) then return nil end
	local first, last = current, current
	while first > 0 and is_table_line(lines[first]) do first = first - 1 end
	while last + 1 < #lines and is_table_line(lines[last + 2]) do last = last + 1 end
	local table_lines = {}
	for index = first + 1, last + 1 do
		table.insert(table_lines, lines[index])
	end
	return first, last + 1, table.concat(table_lines, "\n")
end

function M.format()
	local first, last, text = find_table_range()
	if not first then notify("光标所在位置没有 Markdown 表格", vim.log.levels.WARN) return false end
	local rows, align_or_error = parser.parse(text, "markdown")
	if not rows then notify(align_or_error, vim.log.levels.ERROR) return false end
	local lines, err = formatter.format(rows, {
		align = align_or_error,
		default_alignment = config.default_alignment,
		min_column_width = config.min_column_width,
	})
	if not lines then notify(err, vim.log.levels.ERROR) return false end
	vim.api.nvim_buf_set_lines(0, first, last, false, lines)
	notify("Markdown 表格已对齐")
	return true
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
	vim.api.nvim_create_user_command("MarkdownTable", function() M.convert() end, { desc = "Convert clipboard table to Markdown", force = true })
	vim.api.nvim_create_user_command("MarkdownTableHTML", function() M.convert({ format = "html" }) end, { desc = "Convert HTML clipboard table to Markdown", force = true })
	vim.api.nvim_create_user_command("MarkdownTableFormat", function() M.format() end, { desc = "Align current Markdown table", force = true })
	vim.api.nvim_create_user_command("MarkdownTableVisual", function() M.convert_visual() end, { range = true, desc = "Convert Visual selection to Markdown table", force = true })

	local mappings = type(config.mappings) == "table" and config.mappings or {}
	if mappings.convert then
		vim.keymap.set("n", mappings.convert, function() M.convert() end, { desc = "剪贴板转 Markdown 表格" })
		vim.keymap.set("x", mappings.convert, function()
			-- 先退出 Visual 模式，确保 '< 和 '> 标记已更新，再处理选区。
			local escape = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
			vim.api.nvim_feedkeys(escape, "nx", false)
			vim.schedule(M.convert_visual)
		end, { desc = "选区转 Markdown 表格" })
	end
	if mappings.html then
		vim.keymap.set("n", mappings.html, function() M.convert({ format = "html" }) end, { desc = "HTML 剪贴板转 Markdown 表格" })
	end
	if mappings.format then
		vim.keymap.set("n", mappings.format, M.format, { desc = "格式化 Markdown 表格" })
	end
end

return M
