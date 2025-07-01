-- helpers/debounce.lua
-- Simple debounce utility for SketchyBar Lua configs
local M = {}

function M.debounce(fn, delay)
  local timer = nil
  return function(...)
    local args = { ... }
    if timer then
      timer:stop()
      timer:close()
    end
    timer = vim.loop.new_timer()
    timer:start(delay, 0, function()
      vim.schedule(function()
        fn(unpack(args))
        timer:stop()
        timer:close()
        timer = nil
      end)
    end)
  end
end

return M
