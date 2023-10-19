local langs = require('symbol-usage.langs')
local SymbolKind = vim.lsp.protocol.SymbolKind

---@class ReferencesOpts
---@field enabled boolean
---@field include_declaration? boolean Add number of declaration to count of usage

---@class DefinitionOpts
---@field enabled boolean

---@class ImplementationOpts
---@field enabled boolean

---@alias Formater function(symbol: Symbol): string|table
---@alias VTPosition 'above'|'end_of_line'|'textwidth'
---@alias filterKind function(data: { symbol:table, parent:table, bufnr:integer }): boolean

---User options to `symbol-usage.nvim`
---@class UserOpts
---@field hl? table<string, any> `nvim_set_hl`-like options for highlight virtual text
---@field kinds? lsp.SymbolKind[] Symbol kinds what need to be count (see `lsp.SymbolKind`)
---@field kinds_filter? table<lsp.SymbolKind, filterKind[]> Additional filter for kinds. Recommended use in the filetypes override table.
---@field text_format? Formater Function to format virtual text
---@field references? ReferencesOpts Opts for references
---@field definition? DefinitionOpts Opts for definitions
---@field implementation? ImplementationOpts Opts for implementations
---@field vt_position? VTPosition Virtual text position (`above` by default)
---@field request_pending_text? string|table|false Text to display when request is pending. If `false`, extmark will not be created until the request is finished. Recommended to use with `above` vt_position to avoid "jumping lines".
---@field symbol_request_pos? 'start'|'end' At which position of `symbol.selectionRange` the request to the lsp server should start. Default is `end` (try changing it to `start` if the symbol counting is not correct).
---@field filetypes UserOpts[] To override opts for specific filetypes. Missing field came from common opts

local S = {}

---@type UserOpts
S._default_opts = {
  hl = { link = 'Comment' },
  kinds = { SymbolKind.Function, SymbolKind.Method },
  kinds_filter = {},
  vt_position = 'above',
  request_pending_text = 'loading...',
  text_format = function(symbol)
    local fragments = {}

    if symbol.references then
      local usage = symbol.references <= 1 and 'usage' or 'usages'
      local num = symbol.references == 0 and 'no' or symbol.references
      table.insert(fragments, ('%s %s'):format(num, usage))
    end

    if symbol.definition then
      table.insert(fragments, symbol.definition .. ' defs')
    end

    if symbol.implementation then
      table.insert(fragments, symbol.implementation .. ' impls')
    end

    return table.concat(fragments, ', ')
  end,
  references = { enabled = true, include_declaration = false },
  definition = { enabled = false },
  implementation = { enabled = false },
  symbol_request_pos = 'end',
  filetypes = {
    lua = langs.lua,
    javascript = langs.javascript,
    typescript = langs.javascript,
    typescriptreact = langs.javascript,
    javascriptreact = langs.javascript,
    vue = langs.javascript,
  },
}

S.opts = {}

function S.update(user_opts)
  -- To avoid merging with link
  local hl = user_opts.hl
  S.opts = vim.tbl_deep_extend('force', S._default_opts, user_opts)
  if not hl then
    hl = S.opts.hl
  end
  vim.api.nvim_set_hl(0, 'SymbolUsageText', hl)

  -- so the hl persists across color scheme changes
  vim.api.nvim_create_autocmd('ColorScheme', {
    callback = function()
      vim.api.nvim_set_hl(0, 'SymbolUsageText', hl)
    end,
  })
end

---Get opts for filetype if exists or return default options
---@param bufnr integer Buffer id
---@return UserOpts
function S.get_ft_or_default(bufnr)
  local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')

  return vim.tbl_deep_extend('force', S.opts, S.opts.filetypes[ft] or {})
end

return S
