# markdown-table.nvim

- [Features](#features)
- [Installation](#installation)
    - [Native vim.pack](#native-vimpack)
    - [lazy.nvim](#lazynvim)
- [Default Keymaps](#default-keymaps)
- [Configuration](#configuration)
- [HTML Clipboard Support](#html-clipboard-support)
- [Visual Mode](#visual-mode)
- [Testing](#testing)
- [Limitations](#limitations)
- [License](#license)

> 中文用户可以通过 [README-zh.md](./README-zh.md) 阅读中文说明。

Convert HTML, TSV, and CSV tables from your system clipboard or Visual selection into neatly formatted Markdown tables. Also supports formatting existing Markdown tables.

## Features

- Read HTML tables from the system clipboard (preferred), with automatic fallback to plain-text TSV/CSV.
- Convert HTML, TSV, and CSV data from Visual selections.
- Automatically calculate column widths using `strdisplaywidth()` to correctly handle CJK and other wide characters.
- Handle HTML entities, inline cell tags, `rowspan` / `colspan`, CSV quoting, and escaped commas.
- Escape `|` characters in Markdown cells and convert cell line breaks to `<br>`.
- Format the Markdown table under the cursor while preserving column alignment
markers.

No dependencies on lazy.nvim, plenary.nvim, or any other plugins.

## Installation

### Native vim.pack

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

## Default Keymaps

| Mode   | Keymap       | Description                                             |
|--------|--------------|---------------------------------------------------------|
| Normal | `<leader>mt` | Convert a table from the system clipboard into Markdown |
| Visual | `<leader>mt` | Convert the selected text into a Markdown table         |
| Normal | `<leader>mh` | Force HTML clipboard parsing and convert the table      |
| Normal | `<leader>mf` | Format the Markdown table under the cursor              |

 

You can also use the following commands：

- :MarkdownTable — Convert a table from the system clipboard.
- :MarkdownTableHTML — Force HTML clipboard parsing.
- :MarkdownTableVisual — Convert the current Visual selection.
- :MarkdownTableFormat — Format the Markdown table under the cursor.

## Configuration

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

Set an individual mapping to `false` or `nil` to disable it. To prevent the plugin from defining any default keymaps, set mappings to an empty table.

## HTML Clipboard Support

The plugin prioritizes HTML clipboard data to preserve the structure of tables copied from web pages. If HTML data is unavailable, it falls back to plain text from Neovim's + register.

- macOS: Uses the built-in `pbpaste -Prefer html` command.
- Wayland: Uses `wl-paste --type text/html`.
- X11: Uses `xclip -selection clipboard -t text/html -o`.
- Windows: Attempts to retrieve HTML clipboard data through PowerShell and Windows Forms.

If HTML clipboard data is unavailable, plain-text TSV data copied from web pages can still be converted.

## Visual Mode

Select text containing a TSV, CSV, HTML, or Markdown table, then press <leader>mt.

## Testing

Run the following command from the project root directory:

```sh
nvim --headless -u NONE -l tests/run.lua
```

## Limitations

- The HTML parser is designed for common web tables and is not a complete browser DOM implementation.
- Complex CSS layouts, JavaScript-generated tables, and nested tables may not be fully preserved.
- HTML clipboard access depends on the availability of the corresponding clipboard utilities on your operating system.

## License

MIT
