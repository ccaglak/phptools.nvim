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
  return vim.lsp.util.make_position_params(nil, "utf-16")
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
  if self.parent and self.parent.text then
    self.constructor = self.parent.type == "object_creation_expression" and self.parent.text:match("%((.-)%)") ~= ""
    self.parent.text = self.parent.text:gsub("%b()", "")
  end
end

function Class:get_class_name()
  if self.parent.type == "class_constant_access_expression" and self.parent.node then
    local child = self.parent.node:child()
    if child then
      self.class_name = {
        node = child,
        text = tree.get_text(child),
        range = { child:range() },
      }
      return
    end
  end

  if self.parent.node then
    self.class_name = tree.children(self.parent.node, "name") or tree.children(self.parent.node, "named_type")
  end
end

function Class:find_or_create_class()
  local class_pos = self:class_position()
  if not class_pos then
    self:create_new_class()
    return
  end

  self.file_location = self:get_location(class_pos, "textDocument/definition")

  if self.file_location and self.file_location[1] then
    vim.lsp.util.show_document(self.file_location[1], "utf-8")
  else
    self:create_new_class()
  end
end

-- normalizes path for unix or windows, converts absolute to relative
local function normalize_path(path)
  local sep = _G.sep or (vim.uv.os_uname().sysname == "Windows_NT" and "\\" or "/")

  -- Remove leading slashes to make path relative (prevent absolute paths)
  path = path:gsub("^[\\/]+", "")

  -- Remove trailing slashes
  path = path:gsub("[\\/]+$", "")

  if path ~= "" then
    path = path .. sep
  end
  path = path:gsub("[\\/]+", sep)
  return path
end

function Class:create_new_class()
  if not self.class_name or not self.class_name.text then
    vim.notify("Unable to determine class name", vim.log.levels.ERROR)
    return
  end

  local pre_src = composer.get_prefix_and_src()
  if not pre_src then
    return
  end

  -- Build list of available directories from PSR-4 autoload for reference
  local available_paths = {}
  for _, entry in ipairs(pre_src) do
    table.insert(available_paths, entry.src .. " (" .. entry.prefix .. ")")
  end

  -- Show available paths as notification
  if #available_paths > 0 then
    vim.notify("Available paths:\n" .. table.concat(available_paths, "\n"), vim.log.levels.INFO)
  end

  vim.ui.input({
    prompt = "Enter directory for " .. self.class_name.text .. ".php: ",
    completion = "dir",
    default = vim.fn.expand("%:h"),
  }, function(dir)
    if not dir then
      return
    end
    self:_create_class_in_directory(normalize_path(dir))
  end)
end

function Class:_create_class_in_directory(dir)
  -- Attempt to create directory and handle errors
  local mkdir_result = vim.fn.mkdir(dir, "p")
  if mkdir_result == -1 then
    vim.notify("Failed to create directory: " .. dir, vim.log.levels.ERROR)
    return
  end

  local file_path = dir .. self.class_name.text .. ".php"
  self.file_ns = composer.resolve_namespace(dir)
  local current_ns = composer.generate_use_statement(file_path)

  self:add_to_current_buffer({ current_ns })
  local bufnr = self:get_bufnr(file_path)
  self:add_template_to_buffer(self:template_builder(), bufnr)
  self:finalize_buffer(bufnr)
  _G._filepath_ = file_path
end

function Class:finalize_buffer(bufnr)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_call(0, function()
    vim.cmd("silent! wall! | silent! edit")
  end)
  vim.fn.cursor({ self.constructor and 11 or 9, 9 })
end

function Class:class_position()
  if not self.class_name or not self.class_name.range then
    return nil
  end
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
