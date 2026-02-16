-- GF Migrations: Database migration navigation
-- Handles finding and opening Laravel migration files

local M = {}
local gf_utils = require("phptools.gf.gf_utils")

local PATTERNS = {
  schema_create = "Schema::create%s*%(%s*['\"]([^'\"]+)['\"]",
  schema_table = "Schema::table%s*%(%s*['\"]([^'\"]+)['\"]",
  schema_drop = "Schema::drop%s*%(%s*['\"]([^'\"]+)['\"]",
}

local DIRECTORIES = {
  migrations = "database/migrations",
}

function M.find_migration(table_name)
  if not table_name or table_name == "" then
    return nil
  end

  local primary = DIRECTORIES.migrations .. "/**/*" .. table_name .. "*.php"
  local fallback = "**/*" .. table_name .. "*.php"
  return gf_utils.search_file(primary, fallback)
end

function M.detect_schema_call()
  local line = vim.fn.getline(".")
  return line:match(PATTERNS.schema_create) or
         line:match(PATTERNS.schema_table) or
         line:match(PATTERNS.schema_drop)
end

function M.goto_migration()
  return gf_utils.handle_navigation(
    M.detect_schema_call,
    M.find_migration,
    function(table_name) return "Opened migration for table: " .. table_name end
  )
end

return M
