-- Filter running on each line of the vim buffer
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
      f:write(string.format("%s - %s - %s\n", dateTimeStr(), "line.lua", msg))
      f:flush()
    end
  end
  return logger
end

local logger = setupLogger()

-- }}}

---Handle each line of the text.
---@param line string One line of text from the vim buffer, typically ending with a newline character.
---@param linenr number The line number in the Vim buffer.
---@return string Processed text line.
---  - Return empty string to delete this line.
---  - Include `\n` to insert multiple lines of text.
---  - Remove the trailing `\n` to join the next line.
local function handleOneLine(line, linenr)
  return line -- USER_CODE
end

-- user-code-ended {{{

local function runOnEachLine()
  local curRow = tonumber(os.getenv("START_ROW")) or 1
  for line in io.lines() do
    -- io.lines() strips the newline, so we add it back
    line = line .. "\n"
    local res = handleOneLine(line, curRow)
    io.stdout:write(res)
    curRow = curRow + 1
  end
end

local ok, err = pcall(runOnEachLine)
if not ok then
  logger.log(err)
  os.exit(1)
end

-- vim: set foldmethod=marker foldlevel=0:
-- }}}
