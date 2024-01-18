local tree = require("phptools.treesitter")

local Refactor = {}

function Refactor:new()
  local t = setmetatable({}, { __index = Refactor })
  --
  t.params = vim.lsp.util.make_position_params()
  t.current_file = t.params.textDocument.uri:gsub("file://", "")

  return t
end


--
--
--
function Refactor:run()
  --

  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", false, true, true), "nx", false)
  vim.cmd([['<,'>delete z]])
  local M = Refactor:new()
  vim.ui.select({ "funcInline", "methodInline" }, { prompt = "Select Refactor:" }, function(choice)
    if choice == nil then
      vim.cmd([[put z]])
      return
    end
    if choice == "funcInline" or choice == "methodInline" then
      vim.ui.input({ prompt = "Function Name: ", relative = "editor" }, function(name)
        if choice == nil then
          vim.cmd([[put z]])
          return
        end
        if choice == "methodInline" then
          Refactor:funcInline(name, true)
          return
        end
        Refactor:funcInline(name)
      end)
    end
  end)
end

function Refactor:funcInline(text, visibility)
  local lines = {}
  table.insert(lines, "    function " .. text .. "()")
  local lastline = vim.api.nvim_buf_line_count(0)
  if visibility then
    lines = {}
    visibility = "protected "
    table.insert(lines, "    " .. visibility .. "function " .. text .. "()")
    lastline = lastline - 1
  end
  table.insert(lines, "    {")
  table.insert(lines, "         ")
  table.insert(lines, "    }")
  Refactor:add_to_buffer(lines, lastline)
  vim.cmd([[put z]])
end

function Refactor:add_to_buffer(lines, lastline, bufnr)
  bufnr = bufnr or vim.fn.bufnr(vim.api.nvim_buf_get_name(0))
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.fn.bufload(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, lastline, lastline, true, lines)

  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_call(0, function()
    vim.cmd("silent! write! | edit")
  end)
  vim.fn.cursor({ lastline + 2, 9 })
end

return Refactor
