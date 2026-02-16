local tree = require("phptools.treesitter")
local utils = require("phptools.utils")

local api, fn = vim.api, vim.fn

local Method = {}

local function get_method_template(template_type)
  if template_type == "default" then
    return utils.templates.methods.default
  elseif template_type == "scoped_call_expression" then
    return utils.templates.methods.static
  elseif template_type == "class_constant_access_expression" then
    return utils.templates.methods.enum_case
  end
  return utils.templates.methods.default
end
Method.__index = Method

function Method:new()
  return setmetatable({}, { __index = self })
end

function Method:init()
  self.template = nil
  self.params = utils.make_position_params()
  if self.params and self.params.textDocument and self.params.textDocument.uri then
    self.current_file = self.params.textDocument.uri:gsub("file://", "")
  end
  self.parent, self.method, self.variable_or_scope = self:get_position()
end

function Method:run()
  local instance = self:new()
  instance:init()
  if not instance.parent or not instance.method or not instance.variable_or_scope then
    return
  end

  local method_position = instance:create_position_params(instance.method)

  if instance:find_and_jump_to_definition(method_position) then
    return
  end

  if instance.variable_or_scope.text == "this" then
    instance:handle_this_scope()
  else
    instance:handle_other_scope()
  end
end

function Method:get_position()
  local cnode = tree.cnode()
  local node = cnode.node:parent()
  local node_type = node:type()

  if node_type == "scoped_call_expression" or node_type == "class_constant_access_expression" then
    self.template = node_type
    return node, cnode, tree.children(node, "name")
  end

  if node_type == "member_call_expression" then
    self.template = "default"
    local object = tree.child(node, "object")
    if object then
      if object.node:type() == "parenthesized_expression" then
        local object_creation = tree.children(object.node, "object_creation_expression")
        return object.node, cnode, tree.children(object_creation.node, "name")
      end

      if object.node:type() == "member_access_expression" then
        local name = tree.children(object.node, "name")
        if name then
          local variable_position = self:create_position_params(name)
          self:find_and_jump_to_definition(variable_position)
        end
        local vparent = tree.parent("property_declaration")
        local class = vparent and tree.children(vparent.node, "named_type")
        return node, cnode, class
      end

      if object.node:type() == "variable_name" and tree.get_text(object.node) == "$this" then
        return object.node, cnode, tree.children(object.node, "name")
      end

      if object.node:type() == "variable_name" then
        local variable_position = self:create_position_params(object)
        self:find_and_jump_to_definition(variable_position)
        local class
        local assignment = tree.find_parent(tree.cursor(), "assignment_expression")
        if assignment then
          local right_side = tree.children(assignment.node, "object_creation_expression")
          if right_side then
            class = tree.children(right_side.node, "name")
          end
        end
        if not class then
          -- Check for promoted constructor parameters first
          local parameter = tree.find_parent(tree.cursor(), "property_promotion_parameter")
          if not parameter then
            -- Fall back to regular parameters
            parameter = tree.find_parent(tree.cursor(), "parameter_declaration")
          end
          if parameter then
            class = tree.children(parameter.node, "named_type")
          end
        end

        return node, cnode, class
      end
    end
  end
end

function Method:handle_this_scope()
  local bufnr = self:get_buffer(self.current_file)
  self:add_to_buffer(self:generate_method_lines(self.method.text), bufnr)
end

function Method:handle_other_scope()
  local variable_position = self:create_position_params(self.variable_or_scope)
  if not variable_position then
    self:handle_undefined_class()
    return
  end
  local location = self:find_and_jump_to_definition(variable_position)
  local uri = location and (location.uri or location.targetUri)
  if uri then
    local file_path = uri:gsub("file://", "")
    local bufnr = self:get_buffer(file_path)
    self:add_to_buffer(self:generate_method_lines(self.method.text), bufnr)
  else
    self:handle_undefined_class()
  end
end

function Method:handle_undefined_class()
  _G._filepath_ = nil
  vim.fn.cursor({ self.variable_or_scope.range[1] + 1, self.variable_or_scope.range[2] + 1 }) -- might create bugs
  require("phptools.class"):run()
  self:await_class_creation()
end


local function await(cond, after, opts)
  opts = opts or {}
  local timeout = opts.timeout or 20000
  local interval = opts.interval or 200

  local timer = vim.uv.new_timer()
  if not timer then
    return false
  end

  local elapsed = 0
  local completed = false

  local function cleanup()
    if timer and not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end

  timer:start(
    0,
    interval,
    vim.schedule_wrap(function()
      if completed then
        return
      end

      if cond() then
        completed = true
        cleanup()
        local ok, err = pcall(after)
        if not ok then
          vim.notify("Error in await callback: " .. tostring(err), vim.log.levels.ERROR)
        end
        return
      end

      if elapsed >= timeout then
        completed = true
        cleanup()
        return
      end

      elapsed = elapsed + interval
    end)
  )

  return true
end

function Method:await_class_creation()
  await(function()
    return _G._filepath_ ~= nil
  end, function()
    if not _G._filepath_ then
      vim.notify("Class creation timed out", vim.log.levels.WARN)
      return
    end
    local bufnr = self:get_buffer(_G._filepath_)
    self:add_to_buffer(self:generate_method_lines(self.method.text), bufnr)
  end)
end

function Method:create_position_params(node)
  if not node or not node.range then
    return nil
  end
  return {
    textDocument = utils.make_position_params().textDocument,
    position = {
      character = node.range[2] + 1,
      line = node.range[1],
    },
  }
end

function Method:find_and_jump_to_definition(params, methods)
  methods = methods or "textDocument/definition"
  local results = utils.query(params, methods, 1000)
  if results and #results > 0 then
    utils.jump_to_definition(results[1])
    return results[1]
  end
  return nil
end

function Method:generate_method_lines(method_name)
  local template = get_method_template(self.template)
  if not template then
    vim.notify("No template found for method generation", vim.log.levels.ERROR)
    return {}
  end

  -- Split template string into lines and format with method_name
  local lines = {}
  for line in template:gmatch("[^\n]+") do
    table.insert(lines, string.format(line, method_name))
  end
  return lines
end

function Method:get_buffer(filename)
  return fn.bufexists(filename) ~= 0 and fn.bufnr(filename) or fn.bufadd(filename)
end

function Method:add_to_buffer(lines, bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Check if method already exists in buffer to prevent duplicates
  if self.method and self.method.text then
    local buffer_content = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local method_name = self.method.text
    for _, line in ipairs(buffer_content) do
      if line:match("function%s+" .. method_name .. "%s*%(") then
        -- Method already exists, don't add duplicate
        return
      end
    end
  end

  local lastline = api.nvim_buf_line_count(bufnr)

  -- Use unified buffer operation utility with save
  utils.add_lines_to_buffer(bufnr, lines, true, true)

  api.nvim_set_current_buf(bufnr)
  fn.cursor({ lastline + #lines, 9 })
end

return Method
