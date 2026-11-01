local M = {}

local function trim(value)
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split_delimited(text, delimiter)
	local rows, row, field = {}, {}, {}
	local in_quotes = false
	local i = 1
	local length = #text

	local function push_field()
		table.insert(row, trim(table.concat(field)))
		field = {}
	end

	local function push_row()
		push_field()
		local has_value = false
		for _, value in ipairs(row) do
			if value ~= "" then
				has_value = true
				break
			end
		end
		if has_value then
			table.insert(rows, row)
		end
		row = {}
	end

	while i <= length do
		local char = text:sub(i, i)
		if char == '"' then
			if in_quotes and text:sub(i + 1, i + 1) == '"' then
				table.insert(field, '"')
				i = i + 1
			else
				in_quotes = not in_quotes
			end
		elseif char == delimiter and not in_quotes then
			push_field()
		elseif (char == "\n" or char == "\r") and not in_quotes then
			if char == "\r" and text:sub(i + 1, i + 1) == "\n" then
				i = i + 1
			end
			push_row()
		else
			table.insert(field, char)
		end
		i = i + 1
	end

	if #field > 0 or #row > 0 then
		push_row()
	end

	return rows
end

local function utf8_char(codepoint)
	if codepoint < 0 or codepoint > 0x10FFFF or (codepoint >= 0xD800 and codepoint <= 0xDFFF) then
		return "�"
	end
	if codepoint < 0x80 then
		return string.char(codepoint)
	elseif codepoint < 0x800 then
		return string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + codepoint % 0x40)
	elseif codepoint < 0x10000 then
		return string.char(0xE0 + math.floor(codepoint / 0x1000), 0x80 + math.floor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
	end
	return string.char(0xF0 + math.floor(codepoint / 0x40000), 0x80 + math.floor(codepoint / 0x1000) % 0x40, 0x80 + math.floor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
end

local entities = {
	amp = "&", lt = "<", gt = ">", quot = '"', apos = "'", nbsp = " ",
	copy = "©", reg = "®", trade = "™", ndash = "–", mdash = "—",
	hellip = "…", lsquo = "‘", rsquo = "’", ldquo = "“", rdquo = "”",
}

local function decode_entities(value)
	value = value:gsub("&#[xX]([%da-fA-F]+);", function(hex)
		return utf8_char(tonumber(hex, 16))
	end)
	value = value:gsub("&#(%d+);", function(decimal)
		return utf8_char(tonumber(decimal, 10))
	end)
	return (value:gsub("&([%a]+);", function(name)
		return entities[name] or ("&" .. name .. ";")
	end))
end

local function html_to_rows(html)
	local rows, spans = {}, {}
	local table_depth, in_cell, current_row, current_cell = 0, false, nil, nil
	local skipping = nil

	local function append_text(value)
		if table_depth == 1 and in_cell and not skipping and current_cell then
			table.insert(current_cell.parts, value)
		end
	end

	local function finish_cell()
		if current_row and current_cell then
			current_cell.text = trim(decode_entities(table.concat(current_cell.parts)):gsub("%s+", " "))
			table.insert(current_row.cells, current_cell)
		end
		current_cell, in_cell = nil, false
	end

	local function finish_row()
		if not current_row then return end
		finish_cell()
		local row, column = {}, 1
		for col, span in pairs(spans) do
			if span.remaining > 0 then
				row[col] = span.value
				span.remaining = span.remaining - 1
				if span.remaining == 0 then spans[col] = nil end
			end
		end
		for _, cell in ipairs(current_row.cells) do
			while row[column] ~= nil do column = column + 1 end
			local colspan = math.max(1, cell.colspan or 1)
			local rowspan = math.max(1, cell.rowspan or 1)
			row[column] = cell.text
			if rowspan > 1 then spans[column] = { value = cell.text, remaining = rowspan - 1 } end
			for offset = 1, colspan - 1 do
				row[column + offset] = ""
				if rowspan > 1 then spans[column + offset] = { value = "", remaining = rowspan - 1 } end
			end
			column = column + colspan
		end
		local max_col = 0
		for col in pairs(row) do max_col = math.max(max_col, col) end
		for col = 1, max_col do row[col] = row[col] or "" end
		if max_col > 0 then table.insert(rows, row) end
		current_row = nil
	end

	local function handle_tag(raw)
		local tag = trim(raw)
		local closing = tag:sub(1, 1) == "/"
		if closing then tag = trim(tag:sub(2)) end
		local name = tag:match("^([%w:-]+)")
		if not name then return end
		name = name:lower()
		if name == "script" or name == "style" then
			if closing then skipping = nil else skipping = name end
			return
		end
		if skipping then return end
		if name == "table" then
			if closing then
				table_depth = math.max(0, table_depth - 1)
			else
				table_depth = table_depth + 1
			end
			return
		end
		if table_depth ~= 1 then return end
		if name == "tr" then
			if closing then
				finish_row()
			else
				if current_row then finish_row() end
				current_row = { cells = {} }
			end
		elseif name == "td" or name == "th" then
			if closing then
				finish_cell()
			else
				if not current_row then current_row = { cells = {} } end
				finish_cell()
				local colspan = tonumber(tag:match("colspan%s*=%s*['\"]?(%d+)")) or 1
				local rowspan = tonumber(tag:match("rowspan%s*=%s*['\"]?(%d+)")) or 1
				current_cell = { parts = {}, colspan = colspan, rowspan = rowspan }
				in_cell = true
			end
		elseif in_cell and (name == "br" or name == "p" or name == "div" or name == "li") then
			if name == "br" or closing then append_text(" ") end
		end
	end

	local position = 1
	while true do
		local open_start, open_end = html:find("<[^>]*>", position)
		if not open_start then
			append_text(html:sub(position))
			break
		end
		append_text(html:sub(position, open_start - 1))
		handle_tag(html:sub(open_start + 1, open_end - 1))
		position = open_end + 1
	end
	if current_row then finish_row() end
	return rows
end

local function split_markdown_row(line)
	line = trim(line)
	if line:sub(1, 1) == "|" then line = line:sub(2) end
	if line:sub(-1) == "|" and line:sub(-2, -2) ~= "\\" then line = line:sub(1, -2) end
	local cells, buffer, escaped = {}, {}, false
	for i = 1, #line do
		local char = line:sub(i, i)
		if char == "|" and not escaped then
			table.insert(cells, trim(table.concat(buffer)))
			buffer = {}
		else
			table.insert(buffer, char)
		end
		if char == "\\" then escaped = not escaped else escaped = false end
	end
	table.insert(cells, trim(table.concat(buffer)))
	return cells
end

local function parse_markdown(text)
	local lines, rows, align = vim.split(text, "\n", { plain = true }), {}, {}
	for _, line in ipairs(lines) do
		if line:find("|", 1, true) then
			local cells = split_markdown_row(line)
			local separator = #cells > 0
			for _, cell in ipairs(cells) do
				if not cell:match("^:?-+:?$") then separator = false break end
			end
			if separator and #rows == 1 then
				for i, cell in ipairs(cells) do
					local left, right = cell:sub(1, 1) == ":", cell:sub(-1) == ":"
					align[i] = left and right and "center" or right and "right" or "left"
				end
			else
				table.insert(rows, cells)
			end
		end
	end
	return rows, align
end

function M.parse(text, format)
	if type(text) ~= "string" or text == "" then
		return nil, "输入内容为空"
	end
	format = format or "auto"
	if format == "html" or (format == "auto" and text:lower():find("<table[%s>]")) then
		local rows = html_to_rows(text)
		if #rows == 0 then return nil, "没有在 HTML 中找到有效的 table" end
		return rows, {}, "html"
	elseif format == "markdown" then
		local rows, align = parse_markdown(text)
		if #rows == 0 then return nil, "没有找到 Markdown 表格" end
		return rows, align, "markdown"
	elseif format == "tsv" then
		local rows = split_delimited(text, "\t")
		if #rows == 0 then return nil, "没有找到 TSV 数据" end
		return rows, {}, "tsv"
	elseif format == "csv" then
		local rows = split_delimited(text, ",")
		if #rows == 0 then return nil, "没有找到 CSV 数据" end
		return rows, {}, "csv"
	end

	if text:find("\t", 1, true) then
		return split_delimited(text, "\t"), {}, "tsv"
	elseif text:find("<table[%s>]", 1) then
		local rows = html_to_rows(text)
		if #rows > 0 then return rows, {}, "html" end
	elseif text:find("|", 1, true) then
		local rows, align = parse_markdown(text)
		if #rows > 0 then return rows, align, "markdown" end
	elseif text:find(",", 1, true) then
		return split_delimited(text, ","), {}, "csv"
	end
	return nil, "无法识别表格格式；请确认内容为 HTML、TSV、CSV 或 Markdown 表格"
end

return M
