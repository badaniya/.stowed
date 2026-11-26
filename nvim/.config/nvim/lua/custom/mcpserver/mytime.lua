-- Time MCP Server for MCPHub
-- Provides time-related tools and resources

local mcphub = require 'mcphub'

-- Add current time tool
mcphub.add_tool('mytime', {
  name = 'get_current_time',
  description = 'Get the current date and time in various formats',
  inputSchema = {
    type = 'object',
    properties = {
      format = {
        type = 'string',
        description = "Time format: 'iso', 'unix', 'human', or 'custom'",
        enum = { 'iso', 'unix', 'human', 'custom' },
      },
      timezone = {
        type = 'string',
        description = "Timezone (e.g., 'UTC', 'EST', 'PST')",
      },
      custom_format = {
        type = 'string',
        description = 'Custom strftime format (used with format=custom)',
      },
    },
  },
  handler = function(req, res)
    local format = req.params.format or 'human'
    local timezone = req.params.timezone
    local custom_format = req.params.custom_format

    local current_time = os.time()
    local result

    if format == 'iso' then
      result = os.date('%Y-%m-%dT%H:%M:%SZ', current_time)
    elseif format == 'unix' then
      result = tostring(current_time)
    elseif format == 'custom' and custom_format then
      result = os.date(custom_format, current_time)
    else -- human format (default)
      result = os.date('%A, %B %d, %Y at %I:%M:%S %p', current_time)
    end

    if timezone then
      result = result .. ' (requested timezone: ' .. timezone .. ')'
    end

    return res:text('Current time: ' .. result):send()
  end,
})

-- Add timezone tool
mcphub.add_tool('mytime', {
  name = 'convert_timezone',
  description = 'Convert time between timezones (basic offset calculation)',
  inputSchema = {
    type = 'object',
    properties = {
      time = {
        type = 'string',
        description = 'Time in format YYYY-MM-DD HH:MM:SS',
      },
      from_offset = {
        type = 'number',
        description = 'UTC offset of source timezone (e.g., -5 for EST)',
      },
      to_offset = {
        type = 'number',
        description = 'UTC offset of target timezone (e.g., -8 for PST)',
      },
    },
    required = { 'time', 'from_offset', 'to_offset' },
  },
  handler = function(req, res)
    local time_str = req.params.time
    local from_offset = req.params.from_offset
    local to_offset = req.params.to_offset

    -- Parse the time string (basic implementation)
    local year, month, day, hour, min, sec = time_str:match '(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)'

    if not year then
      return res:error 'Invalid time format. Use YYYY-MM-DD HH:MM:SS'
    end

    local time_table = {
      year = tonumber(year),
      month = tonumber(month),
      day = tonumber(day),
      hour = tonumber(hour),
      min = tonumber(min),
      sec = tonumber(sec),
    }

    local timestamp = os.time(time_table)
    -- Adjust for timezone difference
    local offset_diff = (to_offset - from_offset) * 3600 -- convert hours to seconds
    local converted_timestamp = timestamp + offset_diff

    local converted_time = os.date('%Y-%m-%d %H:%M:%S', converted_timestamp)

    return res:text(string.format('Original: %s (UTC%+d)\nConverted: %s (UTC%+d)', time_str, from_offset, converted_time, to_offset)):send()
  end,
})

-- Add timestamp conversion tool
mcphub.add_tool('mytime', {
  name = 'from_timestamp',
  description = 'Convert Unix timestamp to human-readable date',
  inputSchema = {
    type = 'object',
    properties = {
      timestamp = {
        type = 'number',
        description = 'Unix timestamp to convert',
      },
      format = {
        type = 'string',
        description = 'Output format (default: human-readable)',
      },
    },
    required = { 'timestamp' },
  },
  handler = function(req, res)
    local timestamp = req.params.timestamp
    local format = req.params.format or '%A, %B %d, %Y at %I:%M:%S %p'

    local converted = os.date(format, timestamp)

    return res:text(string.format('Timestamp: %d\nDate: %s', timestamp, converted)):send()
  end,
})

-- Add current time resource
mcphub.add_resource('mytime', {
  name = 'current',
  uri = 'time://current',
  description = 'Current date and time information',
  handler = function(req, res)
    local current_time = os.time()
    local info = {
      unix = current_time,
      iso = os.date('%Y-%m-%dT%H:%M:%SZ', current_time),
      human = os.date('%A, %B %d, %Y at %I:%M:%S %p', current_time),
      utc = os.date('!%Y-%m-%d %H:%M:%S UTC', current_time),
      local_time = os.date('%Y-%m-%d %H:%M:%S %Z', current_time),
    }

    local output = string.format(
      [[
Current Time Information:
========================
Unix Timestamp: %d
ISO Format: %s
Human Readable: %s
UTC: %s
Local Time: %s
]],
      info.unix,
      info.iso,
      info.human,
      info.utc,
      info.local_time
    )

    return res:text(output):send()
  end,
})

-- Add timezone resource template
mcphub.add_resource_template('mytime', {
  name = 'timezone',
  uriTemplate = 'time://timezone/{offset}',
  description = 'Get current time for a specific UTC offset',
  handler = function(req, res)
    local offset = tonumber(req.params.offset)
    if not offset then
      return res:error 'Invalid UTC offset. Use numbers like -5, +3, etc.'
    end

    local current_utc = os.time()
    local offset_time = current_utc + (offset * 3600)
    local formatted = os.date('%Y-%m-%d %H:%M:%S', offset_time)

    return res:text(string.format('Time at UTC%+d: %s', offset, formatted)):send()
  end,
})
