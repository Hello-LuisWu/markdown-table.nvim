local M = {}

local function run(command)
	if vim.fn.executable(command[1]) ~= 1 then return nil end
	local output = vim.fn.system(command)
	if vim.v.shell_error ~= 0 or output == "" then return nil end
	return output
end

function M.get_html()
	if vim.fn.has("mac") == 1 then
		local html = run({ "pbpaste", "-Prefer", "html" })
		if html then return html end
		-- Fallback: read the HTML pasteboard flavor through AppleScript/JXA.
		return run({ "osascript", "-l", "JavaScript", "-e", "ObjC.import('AppKit'); $.NSPasteboard.generalPasteboard.stringForType($.NSPasteboardTypeHTML).js" })
	end
	if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
		return run({ "powershell", "-NoProfile", "-STA", "-Command", "Add-Type -AssemblyName System.Windows.Forms; [Windows.Forms.Clipboard]::GetText([Windows.Forms.TextDataFormat]::Html)" })
	end
	local html = run({ "wl-paste", "--no-newline", "--type", "text/html" })
	if html then return html end
	return run({ "xclip", "-selection", "clipboard", "-o", "-t", "text/html" })
end

function M.get_text()
	local ok, value = pcall(vim.fn.getreg, "+", 1, true)
	if ok and type(value) == "table" then return table.concat(value, "\n") end
	if ok and type(value) == "string" then return value end
	return vim.fn.getreg("+")
end

function M.get(opts)
	opts = opts or {}
	if opts.format == "html" or (opts.format == nil and opts.prefer_html ~= false) then
		local html = M.get_html()
		if html and html:lower():find("<table[%s>]" ) then return html, "html" end
		if opts.format == "html" then return nil, "无法从系统剪贴板读取 HTML 表格；请安装 pbpaste、wl-paste 或 xclip 对应支持" end
	end
	local text = M.get_text()
	if not text or text == "" then return nil, "系统剪贴板为空" end
	return text, opts.format or "auto"
end

return M
