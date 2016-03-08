require 'oled-control/oled'
require 'ruby-mpd'
class String
  def fix(size, padstr=' ')
    self[0...size].ljust(size, padstr) #or ljust
  end
end

display = OLED.new
mpd = MPD.new 'volumio', 6600, {callbacks: true}

mpd.connect

def format_string(song)             # take advantege of that Ý is a small dot in the OLED charset
  format('%s%s%s', song.title.fix(20), song.artist.fix(20), "#{song.date}Ý#{song.album}".fix(20))
end

def length(len)
  case len
    when nil      then '--:--'
    when 0...3600 then "%d:%02d"      % [ len/60, len%60 ]
    else               "%d:%02d:%02d" % [ len/3600, len/60%60, len%60 ]
  end
end

mpd.on :song do |song|
  unless format_string(song) == @last_update
    display.clear
    display.set_cursor(0,0)
    display.write(format_string(song))
  end
  @last_update = format_string(song)
  unless @paused
    display.set_cursor(0,3)
    unless song.time.nil?
      time_display = format('%s/%s',length(song.time.first), length(song.time.last))
      len = 20 - time_display.size
      progress = '='*(((song.time.first.to_f/song.time.last.to_f)*(len-1)).to_i)
      display.write("#{time_display}#{progress}>")
    end
  end
end

mpd.on :state do |state|
  Thread.abort_on_exception = true
  puts state
  if state == :stop
    display.set_cursor(0,3)
    display.write("#{Time.now.strftime("%H:%M")}".center(20))
  end
  if state == :pause
    @paused = true
    display.clear_row 3
    display.set_cursor(5, 3)
    display.write('-- PAUSE --')
  end
  if state == :play
    display.clear_row 3
    @paused = false
  end
end

while 1
  sleep 20
end