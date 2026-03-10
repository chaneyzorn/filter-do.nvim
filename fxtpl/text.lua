-- Filter running on the selected text of the vim buffer
-- The wrapper code will be folded to focus on the user code {{{

local function dateTimeStr()
  local date = os.date("*t")
  return string.format("%04d-%02d-%02d %02d:%02d:%02d", date.year, date.month, date.day, date.hour, date.min, date.sec)
end

local function setupLogger()
  local logFilePath = os.getenv("FX_LOG") or "filter_do.log"

  local f
  local logger = {}
  logger.log = function(msg)
    if not f then
      f = io.open(logFilePath, "a")
    end
    if f then
      f:write(string.format("%s - %s - %s\n", dateTimeStr(), "text.lua", msg))
      f:flush()
    end
  end
  return logger
end

local logger = setupLogger()

-- }}}

---Handle the block of text.
---@param text string A block of text from the vim buffer.
---@return string Processed text block.
local function handleBlock(text)
  return text -- USER_CODE
end

-- user-code-ended {{{

local function runOnBlockText()
  local text = io.stdin:read("*a")
  local res = handleBlock(text)
  io.stdout:write(res)
end

local ok, err = pcall(runOnBlockText)
if not ok then
  logger.log(err)
  os.exit(1)
end

-- vim: set foldmethod=marker foldlevel=0:
-- }}}
