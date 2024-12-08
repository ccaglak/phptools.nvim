local M = {}

local default_word_arrays = {
  { "public", "protected", "private" },
  { "self", "static" },
  { "true", "false" },
  { "require", "require_once", "include" },
  { "abstract", "final" },
  { "class", "interface", "trait" },
  { "string", "int", "float", "bool", "array" },
}

local word_lookup = {}
local operator_toggles = {
  ["=="] = "===",
  ["==="] = "==",
  ["!="] = "!==",
  ["!=="] = "!=",
  [">"] = ">=",
  [">="] = ">",
  ["<"] = "<=",
  ["<="] = "<",
  ["&&"] = "||",
  ["||"] = "&&",
  ["++"] = "--",
  ["--"] = "++",
  ["->"] = "=>",
  ["=>"] = "->",
}
local reverse_operator_toggles = {}

local function build_lookups(word_arrays)
  for _, array in ipairs(word_arrays) do
    for _, word in ipairs(array) do
      word_lookup[word] = array
    end
  end
  for k, v in pairs(operator_toggles) do
    reverse_operator_toggles[v] = k
  end
end

local toggle_word_cache = setmetatable({}, { __mode = "k" })

local function toggle_word(word, direction)
  local cache_key = word .. direction
  if toggle_word_cache[cache_key] then
    return toggle_word_cache[cache_key]
  end

  local array = word_lookup[word]
  if array then
    for i, v in ipairs(array) do
      if v == word then
        local next_word
        if direction == 1 then
          next_word = array[i % #array + 1]
        else
          next_word = array[(i - 2 + #array) % #array + 1]
        end
        toggle_word_cache[cache_key] = next_word
        return next_word
      end
    end
  end
end

local function toggle_operator(line, col, direction)
  local operator = line:sub(col - 1, col + 1)
  local toggle = operator_toggles[operator] or (direction == -1 and reverse_operator_toggles[operator])
  if toggle then
    return line:sub(1, col - 2) .. toggle .. line:sub(col + 2), true
  end
  return line, false
end

local function toggle_words(direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]

  local new_line, toggled = toggle_operator(line, col + 1, direction)
  if toggled then
    vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })
    return
  end

  local word = vim.fn.expand("<cword>")
  local next_word = toggle_word(word, direction)

  if next_word then
    local start_col = line:find(word, 1, true) - 1
    local end_col = start_col + #word
    vim.api.nvim_buf_set_text(bufnr, row - 1, start_col, row - 1, end_col, { next_word })
  else
    local key = direction == 1 and "<C-a>" or "<C-x>"
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "n", false)
  end
end

function M.setup(config)
  local custom_toggles = config.custom_toggles or {}
  local word_arrays = vim.tbl_deep_extend("force", default_word_arrays, custom_toggles)

  build_lookups(word_arrays)

  local mappings = {
    ["<C-a>"] = function()
      toggle_words(1)
    end,
    ["<C-x>"] = function()
      toggle_words(-1)
    end,
  }
  for key, func in pairs(mappings) do
    vim.keymap.set("n", key, func, {
      noremap = true,
      silent = true,
      desc = "Toggle PHP words or increment/decrement",
    })
  end
end

return M
