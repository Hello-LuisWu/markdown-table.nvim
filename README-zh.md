# markdown-table.nvim

- [功能](#功能)
- [安装](#安装)
    - [Neovim 原生 vim.pack](#neovim-原生-vimpack)
    - [lazy.nvim](#lazynvim)
- [默认快捷键](#默认快捷键)
- [配置](#配置)
- [剪贴板 HTML 支持](#剪贴板-html-支持)
- [Visual 模式](#visual-模式)
- [测试](#测试)
- [限制](#限制)
- [License](#license)


将系统剪贴板或 Visual 选区中的 HTML、TSV、CSV 表格转换为排版整齐的 Markdown 表格，并格式化已有 Markdown 表格。

## 功能

- 从系统剪贴板读取 HTML 表格（优先）或纯文本 TSV/CSV。
- 转换 Visual 选区中的 HTML、TSV、CSV 数据。
- 自动计算列宽，使用 `strdisplaywidth()` 处理中文等宽字符。
- 处理 HTML 实体、单元格内标签、`rowspan` / `colspan`、CSV 引号和转义逗号。
- 转义 Markdown 单元格中的 `|`，将单元格换行转换为 `<br>`。
- 格式化光标所在的 Markdown 表格，并保留列对齐标记。
- 不依赖 lazy.nvim、plenary.nvim 或其他插件。

## 安装

### Neovim 原生 vim.pack

```lua
vim.pack.add({
  "https://github.com/Hello-LuisWu/markdown-table.nvim",
})

require("markdown_table").setup({})
```

### lazy.nvim

```lua
{
  "Hello-LuisWu/markdown-table.nvim",
  config = function()
    require("markdown_table").setup({})
  end,
}
```

## 默认快捷键

| 模式 | 快捷键 | 功能 |
| --- | --- | --- |
| Normal | `<leader>mt` | 将剪贴板表格转换为 Markdown |
| Visual | `<leader>mt` | 将选区转换为 Markdown |
| Normal | `<leader>mh` | 强制读取 HTML 剪贴板并转换 |
| Normal | `<leader>mf` | 格式化光标所在 Markdown 表格 |

也可以使用命令：

- `:MarkdownTable`：转换剪贴板表格。
- `:MarkdownTableHTML`：强制读取 HTML 剪贴板。
- `:MarkdownTableVisual`：转换 Visual 选区。
- `:MarkdownTableFormat`：格式化当前 Markdown 表格。

## 配置

```lua
require("markdown_table").setup({
  mappings = {
    convert = "<leader>mt",
    html = "<leader>mh",
    format = "<leader>mf",
  },
  clipboard = {
    prefer_html = true,
  },
  default_alignment = "left", -- left | center | right
  min_column_width = 3,
  notify = true,
})
```

将某个快捷键设为 `false` 或 `nil` 可关闭对应映射。若不希望插件覆盖已有映射，可将 `mappings` 设为空表。

## 剪贴板 HTML 支持

插件优先读取 HTML 剪贴板格式，以保留网页表格结构；如果不可用，则回退到 Neovim `+` 寄存器中的纯文本。

- macOS：使用系统自带的 `pbpaste -Prefer html`。
- Wayland：使用 `wl-paste --type text/html`。
- X11：使用 `xclip -selection clipboard -t text/html -o`。
- Windows：尝试使用 PowerShell 与 Windows Forms 读取 HTML 格式。

如果 HTML 格式不可用，网页复制的 TSV 纯文本仍可正常转换。

## Visual 模式

选中 TSV、CSV、HTML 或 Markdown 表格文本，再按 `<leader>mt`。行选择适合完整表格；字符选择会只替换选中的字符范围。

## 测试

在项目根目录运行：

```sh
nvim --headless -u NONE -l tests/run.lua
```

## 限制

- HTML 解析器针对常见网页表格设计，不是完整的浏览器 DOM 实现。
- 复杂 CSS 布局、JavaScript 动态表格和嵌套表格不保证完全还原。
- 剪贴板 HTML 格式读取取决于操作系统剪贴板工具是否可用。

## License

MIT
