#! /usr/bin/env ruby
# https://unix.stackexchange.com/a/632345
#
# Ruby script to merge zsh histories. In case of duplicates, it removes the old timestamps.
# It should do fine with multi-line commands.
# Make backups of your backups before running this script!
#
# ./merge_zsh_histories.rb zsh_history_*.bak ~/.zsh_history > merged_zsh_history

MULTILINE_COMMAND = "TO_BE_REMOVED_#{Time.now.to_i}"

commands = Hash.new([0,0])

ARGV.sort.each do |hist|
  $stderr.puts "Parsing '#{hist}'"
  content = File.read(hist)
  content.scrub!("#")
  content.gsub!(/\\\n(?!:\s*\d{10,})/, MULTILINE_COMMAND)
  should_be_empty = content.each_line.grep_v(/^:/) + content.each_line.grep(/(?<!^): \d{10,}/)
  raise "Problem with those lines : #{should_be_empty}" unless should_be_empty.empty?
  content.each_line do |line|
    description, command = line.split(';', 2)
    _, time, duration = description.split(':').map(&:to_i)
    old_time, _old_duration = commands[command]
    if time > old_time
      commands[command] = [time, duration]
    end
  end
end

commands.sort_by{|_, time_duration| time_duration}.each{|command, (time, duration)|
  puts ':%11d:%d;%s' % [time, duration, command.gsub(MULTILINE_COMMAND, "\\\n")]
}
