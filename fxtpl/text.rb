# Filter running on the selected text of the vim buffer
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

# Handle the block of text.
#
# @param text [String] A block of text from the vim buffer.
# @return [String] Processed text block.
def handle_block(text)
  text # USER_CODE
end

# user-code-ended {{{

def run_on_block_text
  res = handle_block($stdin.read)
  $stdout.write(res)
end

begin
  run_on_block_text
rescue => e
  $logger.error(e.message)
  exit 1
end

# vim: set foldmethod=marker foldlevel=0:
# }}}
