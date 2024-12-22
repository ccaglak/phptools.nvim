local tree = require("phptools.treesitter")
local composer = require("phptools.composer")

local Class = {}

Class.templates = {
  class_interface_clause = "interface",
  base_clause = "class",
  object_creation_expression = "class",
  scoped_call_expression = "class",
  use_declaration = "trait",
  class_constant_access_expression = "enum",
  simple_parameter = "class",
}

local function make_position_params()
  if vim.fn.has("nvim-0.11") == 1 then
    return vim.lsp.util.make_position_params(nil, "utf-16")
  end
  return vim.lsp.util.make_position_params()
end

function Class:new()
  return setmetatable({
    params = make_position_params(),
    constructor = false,
  }, { __index = self })
end

function Class:run()
  local instance = self:new()
  instance.parent = instance:get_parent()
  if not instance.parent then
    return
  end

  instance:process_parent()
  instance:get_class_name()
  instance:find_or_create_class()
end

function Class:process_parent()
  self.constructor = self.parent.type == "object_creation_expression" and self.parent.text:match("%((.-)%)") ~= ""
  self.parent.text = self.parent.text:gsub("%b()", "")
end

function Class:get_class_name()
  self.class_name = self.parent.type == "class_constant_access_expression"
      and {
        node = self.parent.node:child(),
        text = tree.get_text(self.parent.node:child()),
        range = { self.parent.node:child():range() },
      }
    or tree.children(self.parent.node, "name")
    or tree.children(self.parent.node, "named_type")
end

function Class:find_or_create_class()
  self.file_location = self:get_location(self:class_position(), "textDocument/definition")

  if self.file_location[1] then
    vim.lsp.util.show_document(self.file_location[1], "utf-8")
  else
    self:create_new_class()
  end
end

-- normalizes path for unix or windows
local function normalize_path(path)
  path = path:gsub("[\\/]+$", "")
  if path ~= "" then
    path = path .. sep
  end
  path = path:gsub("[\\/]+", sep)
  return path
end

function Class:create_new_class()
  local pre_src = composer.get_prefix_and_src()
  if not pre_src then
    return
  end

  -- local rt = vim.fn.expand("%:h")
  -- if rt == "." then
  --   rt = "/"
  -- end

  vim.ui.input({
    prompt = "Directory for " .. self.class_name.text .. ".php",
    completion = "dir",
    default = vim.fn.expand("%:h"),
  }, function(dir)
    if not dir then
      return
    end
    dir = normalize_path(dir)
    vim.fn.mkdir(dir, "p")

    local file_path = dir .. self.class_name.text .. ".php"
    self.file_ns = composer.resolve_namespace(dir)
    local current_ns = composer.generate_use_statement(file_path)

    self:add_to_current_buffer({ current_ns })
    local bufnr = self:get_bufnr(file_path)
    self:add_template_to_buffer(self:template_builder(), bufnr)
    self:finalize_buffer(bufnr)
    _G._filepath_ = file_path
  end)
end

function Class:finalize_buffer(bufnr)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_call(0, function()
    vim.cmd("silent! wall! | edit")
  end)
  vim.fn.cursor({ self.constructor and 11 or 9, 9 })
end

function Class:class_position()
  return {
    textDocument = self.params.textDocument,
    position = { character = self.class_name.range[2] + 1, line = self.class_name.range[1] },
  }
end

function Class:get_bufnr(filename)
  return vim.fn.bufexists(filename) ~= 0 and vim.fn.bufnr(filename) or vim.fn.bufadd(filename)
end

function Class:add_template_to_buffer(lines, bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.fn.bufload(bufnr)
    local flat_lines = {}
    for _, line in ipairs(lines) do
      for subline in line:gmatch("[^\r\n]+") do
        table.insert(flat_lines, subline)
      end
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, flat_lines)
  end
end

function Class:add_to_current_buffer(lines)
  vim.api.nvim_buf_set_lines(0, self:get_insertion_point(), self:get_insertion_point(), true, lines)
end

function Class:get_parent()
  for _, type in ipairs({
    "object_creation_expression",
    "base_clause",
    "class_interface_clause",
    "use_declaration",
    "class_constant_access_expression",
    "scoped_call_expression",
    "simple_parameter",
  }) do
    local parent = tree.parent(type)
    if parent and parent.type == type then
      return parent
    end
  end
end

function Class:template_builder()
  if self.parent.type == "class_constant_access_expression" and string.match(self.parent.text, "class") then
    self.parent.type = "" -- this will result template to default to class
  end

  local template = self.templates[self.parent.type] or "class"
  local tmpl = {
    "<?php",
    "",
    "declare(strict_types=1);",
    "",
    self.file_ns,
    "",
    template .. " " .. self.class_name.text,
    "{",
    self.constructor and "    public function __construct()\n    {\n        //\n    }" or "    //",
    "}",
  }
  return tmpl
end

function Class:get_location(params, method)
  local results = vim.lsp.buf_request_sync(0, method, params, 1000)
  return results and results[1] and results[1].result
end

function Class:get_insertion_point()
  local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local insertion_point = 2

  for i, line in ipairs(content) do
    if vim.fn.match(line, "^\\(declare\\)") >= 0 then
      insertion_point = i
    elseif vim.fn.match(line, "^\\(namespace\\)") >= 0 then
      return i, vim.fn.match(line, "^\\(namespace\\)")
    elseif vim.fn.match(line, "^\\(use\\|class\\|final\\|interface\\|abstract\\|trait\\|enum\\)") >= 0 then
      return insertion_point
    end
  end

  return insertion_point, nil
end

return Class
