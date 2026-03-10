# Filter running on each line of the vim buffer
# The wrapper code will be folded to focus on the user code {{{

require 'logger'
require 'pathname'

def setup_logger
  script_path = Pathname.new(__FILE__).expand_path
  script_name = script_path.basename.to_s
  log_file_path = ENV['FX_LOG'] || script_path.dirname.join('filter_do.log').to_s

  logger = Logger.new(log_file_path)
  logger.level = Logger::INFO
  logger.formatter = proc do |severity, datetime, progname, msg|
    "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} - #{script_name} - #{msg}\n"
  end
  logger
end

$logger = setup_logger

# }}}

# Handle each line of the text.
#
# @param line [String] One line of text from the vim buffer, typically ending with a newline character.
# @param linenr [Integer] The line number in the Vim buffer.
# @return [String] Processed text line.
#   - Return empty string to delete this line.
#   - Include `\n` to insert multiple lines of text.
#   - Remove the trailing `\n` to join the next line.
def handle_one_line(line, linenr)
  line # USER_CODE
end

# user-code-ended {{{

def run_on_each_line
  cur_row = ENV.fetch('START_ROW', '1').to_i
  $stdin.each_line do |line|
    res = handle_one_line(line, cur_row) || ''
    $stdout.write(res)
    cur_row += 1
  end
end

begin
  run_on_each_line
rescue => e
  $logger.error(e.message)
  exit 1
end

# vim: set foldmethod=marker foldlevel=0:
# }}}
