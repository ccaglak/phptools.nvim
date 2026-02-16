-- GF Symfony: Symfony framework-specific navigation
-- Handles finding and opening Symfony-related files (services, config, entities, etc.)

local M = {}
local gf_utils = require("phptools.gf.gf_utils")
local np = gf_utils.normalize_path
local rp = gf_utils.relative_path

local PATTERNS = {
  -- Service/DI container: @service_name
  service = "@([a-z_][a-z0-9_.]*)",

  -- Config function: config('app.name')
  config = "config%s*%(%s*['\"]([^'\"]+)['\"]%s*%)",

  -- Service reference: service('my.service')
  service_ref = "service%s*%(%s*['\"]([a-z_][a-z0-9._]*)['\"]%s*%)",

  -- Entity reference: find('App\Entity\User')
  entity_class = "(?:find|getRepository)%s*%(%s*['\"]([^'\"]+)['\"]",
}

local DIRECTORIES = {
  entities = { "src/Entity", "app/Entity", "src/AppBundle/Entity" },
  services = { "src/Service", "app/Service", "src/AppBundle/Service" },
  controllers = { "src/Controller", "app/Controller", "src/AppBundle/Controller" },
  listeners = { "src/EventListener", "app/EventListener", "src/AppBundle/EventListener" },
  forms = { "src/Form", "app/Form", "src/AppBundle/Form" },
  validators = { "src/Validator", "app/Validator", "src/AppBundle/Validator" },
  config = { "config", "app/config" },
}

function M.find_service_class(service_name)
  -- Find service class from service name or fully qualified class name
  if not service_name or service_name == "" then
    return nil
  end

  -- Check if it's a fully qualified class name
  if service_name:match("\\") then
    return gf_utils.find_php_class_file(service_name)
  end

  -- Try to find service in common directories
  local root = gf_utils.get_project_root() or vim.fn.getcwd()

  for _, service_dir in ipairs(DIRECTORIES.services) do
    -- Try converting service name to class name: my.service -> MyService
    local class_name = service_name:gsub("_", " "):gsub("(%a)([%a%d]*)", function(a, b)
      return a:upper() .. b
    end):gsub(" ", "")

    local service_file = np(root .. "/" .. service_dir .. "/" .. class_name .. ".php")
    if vim.fn.filereadable(service_file) == 1 then
      return service_file
    end
  end

  -- Fallback: search project for the service class
  local filename = service_name:match("([^.]+)$")
  if filename then
    local class_name = filename:gsub("_", " "):gsub("(%a)([%a%d]*)", function(a, b)
      return a:upper() .. b
    end):gsub(" ", "")

    local pattern = "**/src/**/" .. class_name .. ".php"
    local results = vim.fn.globpath(root, pattern, 0, 1)
    if results and #results > 0 then
      return results[1]
    end
  end

  return nil
end

function M.find_entity(entity_name)
  -- Find Doctrine entity file
  if not entity_name or entity_name == "" then
    return nil
  end

  -- If it's a fully qualified class name, use class finder
  if entity_name:match("\\") then
    return gf_utils.find_php_class_file(entity_name)
  end

  -- Convert to class name format
  local class_name = entity_name:gsub("_", " "):gsub("(%a)([%a%d]*)", function(a, b)
    return a:upper() .. b
  end):gsub(" ", "")

  local root = gf_utils.get_project_root() or vim.fn.getcwd()

  -- Try common entity directories
  for _, entity_dir in ipairs(DIRECTORIES.entities) do
    local entity_file = np(root .. "/" .. entity_dir .. "/" .. class_name .. ".php")
    if vim.fn.filereadable(entity_file) == 1 then
      return entity_file
    end
  end

  -- Fallback: search project
  local pattern = "**/Entity/**/" .. class_name .. ".php"
  local results = vim.fn.globpath(root, pattern, 0, 1)
  if results and #results > 0 then
    return results[1]
  end

  return nil
end

function M.find_config_file(config_key)
  -- Find config file by key
  if not config_key or config_key == "" then
    return nil
  end

  local root = gf_utils.get_project_root() or vim.fn.getcwd()
  local parts = {}

  -- Split by dots: app.name -> config/app.yaml
  for part in config_key:gmatch("([^.]+)") do
    table.insert(parts, part)
  end

  if #parts == 0 then
    return nil
  end

  local config_file = np(root .. "/config/" .. parts[1] .. ".yaml")
  if vim.fn.filereadable(config_file) == 1 then
    return config_file
  end

  -- Try .yml extension
  config_file = np(root .. "/config/" .. parts[1] .. ".yml")
  if vim.fn.filereadable(config_file) == 1 then
    return config_file
  end

  return nil
end

function M.detect_symfony_reference()
  local line = vim.fn.getline(".")

  -- Try service references: @service_name or service('name')
  local service_ref = line:match("@([a-z_][a-z0-9_.]*)")
  if service_ref then
    return service_ref
  end

  -- Try config keys
  local config_ref = line:match('config%s*%(%s*[\'"]([^\'"]+)[\'"]%s*%)')
  if config_ref then
    return config_ref
  end

  -- Try service() function
  service_ref = line:match('service%s*%(%s*[\'"]([^\'"]+)[\'"]%s*%)')
  if service_ref then
    return service_ref
  end

  -- Try entity classes
  local entity_ref = line:match('(?:Entity\\|getRepository|find)%s*%(%s*[\'"]([^\'"]+)[\'"]')
  if entity_ref then
    return entity_ref
  end

  return nil
end

function M.goto_symfony_reference()
  local reference = M.detect_symfony_reference()

  if not reference then
    return false
  end

  -- Try as service first
  local file = M.find_service_class(reference)
  if file then
    vim.cmd("edit " .. file)
    gf_utils.notify_info("Opened service: " .. reference)
    return true
  end

  -- Try as entity
  file = M.find_entity(reference)
  if file then
    vim.cmd("edit " .. file)
    gf_utils.notify_info("Opened entity: " .. reference)
    return true
  end

  -- Try as config
  file = M.find_config_file(reference)
  if file then
    vim.cmd("edit " .. file)
    gf_utils.notify_info("Opened config: " .. reference)
    return true
  end

  return false
end

function M.browse_services()
  -- Browse available services
  local root = gf_utils.get_project_root() or vim.fn.getcwd()

  local services = {}
  for _, service_dir in ipairs(DIRECTORIES.services) do
    local service_files = vim.fn.globpath(root, service_dir .. "/**/*.php", 0, 1)
    if service_files and #service_files > 0 then
      for _, file in ipairs(service_files) do
        table.insert(services, file)
      end
    end
  end

  if #services == 0 then
    gf_utils.notify_warn("No services found")
    return false
  end

  vim.ui.select(services, {
    prompt = "Select service: ",
    format_item = function(item)
      return rp(item)
    end,
  }, function(choice)
    if choice then
      vim.cmd("edit " .. choice)
      gf_utils.notify_info("Opened service")
    end
  end)

  return true
end

function M.browse_entities()
  -- Browse available entities
  local root = gf_utils.get_project_root() or vim.fn.getcwd()

  local entities = {}
  for _, entity_dir in ipairs(DIRECTORIES.entities) do
    local entity_files = vim.fn.globpath(root, entity_dir .. "/**/*.php", 0, 1)
    if entity_files and #entity_files > 0 then
      for _, file in ipairs(entity_files) do
        table.insert(entities, file)
      end
    end
  end

  if #entities == 0 then
    gf_utils.notify_warn("No entities found")
    return false
  end

  vim.ui.select(entities, {
    prompt = "Select entity: ",
    format_item = function(item)
      return rp(item)
    end,
  }, function(choice)
    if choice then
      vim.cmd("edit " .. choice)
      gf_utils.notify_info("Opened entity")
    end
  end)

  return true
end

return M
