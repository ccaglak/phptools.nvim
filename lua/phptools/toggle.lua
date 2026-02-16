local M = {}

-- Direction constants
local DIRECTION_UP = 1
local DIRECTION_DOWN = -1

-- Default word toggle groups
local DEFAULT_WORD_ARRAYS = {
  { "public", "protected", "private" },
  { "self", "static" },
  { "true", "false" },
  { "require", "require_once", "include" },
  { "abstract", "final" },
  { "class", "interface", "trait", "enum" },
  { "string", "int", "float", "bool", "array" },
}

-- Operator toggle mappings (bidirectional)
local OPERATOR_TOGGLES = {
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

-- Cache for word lookups (word -> array mapping)
local word_lookup = {}
-- Cache for operator lookups (operator -> toggle mapping)
local reverse_operator_toggles = {}
-- Cache for toggle results (nested: word -> {[direction] -> result})
local toggle_word_cache = {}

local function build_lookups(word_arrays)
  -- Clear previous lookups
  word_lookup = {}
  reverse_operator_toggles = {}
  toggle_word_cache = setmetatable({}, { __mode = "k" })

  -- Build word lookup: maps each word to its toggle array
  for _, array in ipairs(word_arrays) do
    for _, word in ipairs(array) do
      word_lookup[word] = array
    end
  end

  -- Build reverse operator toggles for direction == -1 lookups
  for k, v in pairs(OPERATOR_TOGGLES) do
    reverse_operator_toggles[v] = k
  end
end

local function toggle_word(word, direction)
  -- Validate inputs
  if not word or #word == 0 then
    return nil
  end

  -- Check cache first (nested structure for efficiency)
  if toggle_word_cache[word] and toggle_word_cache[word][direction] then
    return toggle_word_cache[word][direction]
  end

  local array = word_lookup[word]
  if not array then
    return nil
  end

  -- Find current word position in its toggle array
  for i, v in ipairs(array) do
    if v == word then
      -- Calculate next word position based on direction
      local next_idx
      if direction == DIRECTION_UP then
        next_idx = i % #array + 1
      else
        next_idx = (i - 2 + #array) % #array + 1
      end

      local next_word = array[next_idx]
      -- Cache result
      if not toggle_word_cache[word] then
        toggle_word_cache[word] = {}
      end
      toggle_word_cache[word][direction] = next_word
      return next_word
    end
  end

  return nil
end

local function toggle_operator(line, col, direction)
  if not line or col < 1 or col > #line then
    return line, false
  end

  -- Try to find an operator at or around the cursor position
  -- Check for 3-character operators first, then 2-character, then 1-character
  local operator = nil
  local op_start = nil
  local op_end = nil

  -- Try positions for 3-character operators
  for start_offset = -2, 0 do
    local start = col + start_offset
    if start >= 1 and start + 2 <= #line then
      local candidate = line:sub(start, start + 2)
      if OPERATOR_TOGGLES[candidate] then
        operator = candidate
        op_start = start
        op_end = start + 2
        break
      end
    end
  end

  -- Try 2-character operators if no 3-char found
  if not operator then
    for start_offset = -1, 0 do
      local start = col + start_offset
      if start >= 1 and start + 1 <= #line then
        local candidate = line:sub(start, start + 1)
        if OPERATOR_TOGGLES[candidate] then
          operator = candidate
          op_start = start
          op_end = start + 1
          break
        end
      end
    end
  end

  -- Try 1-character operators if no longer operator found
  if not operator then
    local candidate = line:sub(col, col)
    if OPERATOR_TOGGLES[candidate] then
      operator = candidate
      op_start = col
      op_end = col
    end
  end

  if not operator then
    return line, false
  end

  -- Look up toggle for this operator
  local toggle = OPERATOR_TOGGLES[operator]
  if not toggle then
    -- For DIRECTION_DOWN, also try reverse lookup
    if direction == DIRECTION_DOWN then
      toggle = reverse_operator_toggles[operator]
    end
  end

  if toggle then
    return line:sub(1, op_start - 1) .. toggle .. line:sub(op_end + 1), true
  end

  return line, false
end

local function toggle_words(direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))

  -- Get current line (1-indexed row from cursor, 0-indexed for API)
  local lines = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)
  if not lines or #lines == 0 then
    return
  end

  local line = lines[1]
  if not line then
    return
  end

  -- Try operator toggle first (3-character operators like ==, ===, etc.)
  local new_line, toggled = toggle_operator(line, col + 1, direction)
  if toggled then
    vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })
    return
  end

  -- Fall back to word toggle
  local word = vim.fn.expand("<cword>")
  local next_word = toggle_word(word, direction)

  if next_word then
    -- Find word position in line and replace it
    -- Find the occurrence closest to cursor position (not just the first one)
    local start_col = nil
    local search_pos = 1
    local closest_pos = nil
    local closest_distance = math.huge

    -- Search for all occurrences and find the one closest to cursor
    while true do
      local pos = line:find(word, search_pos, true)
      if not pos then
        break
      end

      -- Calculate distance from cursor column (col is 0-indexed)
      local distance = math.abs(pos - 1 - col)
      if distance < closest_distance then
        closest_distance = distance
        closest_pos = pos
      end

      search_pos = pos + 1
    end

    if closest_pos then
      start_col = closest_pos - 1 -- Convert to 0-indexed
      local end_col = start_col + #word
      vim.api.nvim_buf_set_text(bufnr, row - 1, start_col, row - 1, end_col, { next_word })
    end
  else
    -- Fall back to default vim increment/decrement
    local key = direction == DIRECTION_UP and "<C-a>" or "<C-x>"
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "n", false)
  end
end

function M.setup(config)
  config = config or {}
  local custom_toggles = config.custom_toggles or {}

  -- Merge default word arrays with custom toggles
  local word_arrays = vim.tbl_deep_extend("force", DEFAULT_WORD_ARRAYS, custom_toggles)

  -- Build lookup tables for word and operator toggles
  build_lookups(word_arrays)

  -- Setup keymaps for toggle functionality
  local keymap_opts = {
    noremap = true,
    silent = true,
    desc = "Toggle PHP words or increment/decrement",
  }

  vim.keymap.set("n", "<C-a>", function()
    toggle_words(DIRECTION_UP)
  end, keymap_opts)

  vim.keymap.set("n", "<C-x>", function()
    toggle_words(DIRECTION_DOWN)
  end, keymap_opts)
end

-- Export internal functions for testing
M._toggle_word = toggle_word
M._toggle_operator = toggle_operator
M._toggle_words = toggle_words

return M
