local M = {}

local function display_width(value)
	if vim and vim.fn and vim.fn.strdisplaywidth then
		return vim.fn.strdisplaywidth(value)
	end
	return #value
end

local function escape_pipes(value)
	local out, escaped = {}, false
	for i = 1, #value do
		local char = value:sub(i, i)
		if char == "|" and not escaped then table.insert(out, "\\") end
		table.insert(out, char)
		if char == "\\" then escaped = not escaped else escaped = false end
	end
	return table.concat(out)
end

local function normalize_cell(value)
	value = tostring(value or "")
	value = value:gsub("\r\n", "\n"):gsub("\r", "\n")
	value = value:gsub("\n", "<br>")
	value = escape_pipes(value)
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.format(rows, opts)
	opts = opts or {}
	if type(rows) ~= "table" or #rows == 0 then return nil, "沒有可格式化的表格" end
	local column_count = 0
	for _, row in ipairs(rows) do column_count = math.max(column_count, #row) end
	if column_count == 0 then return nil, "表格沒有欄位" end

	local normalized, widths = {}, {}
	for col = 1, column_count do widths[col] = math.max(3, tonumber(opts.min_column_width) or 3) end
	for row_index, row in ipairs(rows) do
		normalized[row_index] = {}
		for col = 1, column_count do
			local cell = normalize_cell(row[col])
			normalized[row_index][col] = cell
			widths[col] = math.max(widths[col], display_width(cell))
		end
	end

	local align = opts.align or {}
	local output = {}
	local function make_row(row)
		local cells = {}
		for col = 1, column_count do
			local cell = row[col] or ""
			local padding = math.max(0, widths[col] - display_width(cell))
			local mode = align[col] or opts.default_alignment or "left"
			if mode == "right" then
				cell = string.rep(" ", padding) .. cell
			elseif mode == "center" then
				local left = math.floor(padding / 2)
				cell = string.rep(" ", left) .. cell .. string.rep(" ", padding - left)
			else
				cell = cell .. string.rep(" ", padding)
			end
			cells[col] = cell
		end
		return "| " .. table.concat(cells, " | ") .. " |"
	end

	output[#output + 1] = make_row(normalized[1])
	local separators = {}
	for col = 1, column_count do
		local width = widths[col]
		local mode = align[col] or opts.default_alignment or "left"
		if mode == "center" then
			separators[col] = ":" .. string.rep("-", math.max(1, width - 2)) .. ":"
		elseif mode == "right" then
			separators[col] = string.rep("-", math.max(2, width - 1)) .. ":"
		else
			separators[col] = ":" .. string.rep("-", math.max(2, width - 1))
		end
	end
	output[#output + 1] = "| " .. table.concat(separators, " | ") .. " |"
	for row_index = 2, #normalized do
		output[#output + 1] = make_row(normalized[row_index])
	end
	return output
end

return M
