-- main module file
local mthd = require("phpUtils.method")
local clss = require("phpUtils.class")
local cmpsr = require("phpUtils.composer")

local M = {}

M.method = function()
    mthd.method()
end

M.class = function()
    clss.class()
end

M.commands = function()
    cmpsr.scripts()
end

return M
