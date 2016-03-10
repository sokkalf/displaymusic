require 'oled-control/oled'
require 'ruby-mpd'
require 'yaml'

class String
  def fix(size, padstr=' ')
    self[0...size].ljust(size, padstr) #or ljust
  end
end
@config = YAML.load_file('config.yml')

display = OLED.new(@config['display']['i2c-bus'], @config['display']['i2c-address'],
                   @config['display']['flipped'])
display.set_contrast(@config['display']['contrast'])

mpd = MPD.new @config['mpd']['host'], @config['mpd']['port'], {callbacks: true}

mpd.connect

def format_string(song)             # take advantage of that Ý is a small dot in the OLED charset
  format('%s%s%s', song.title.fix(20), song.artist.fix(20), "#{song.date}Ý#{song.album}".fix(20))
end

def length(len)
  case len
    when nil      then '--:--'
    when 0...3600 then "%d:%02d"      % [ len/60, len%60 ]
    else               "%d:%02d:%02d" % [ len/3600, len/60%60, len%60 ]
  end
end

def update_songinfo(display, song)
  unless format_string(song) == @last_update
    display.clear
    display.set_cursor(0,0)
    display.write(format_string(song))
  end
  @last_update = format_string(song)
end

mpd.on :song do |song|
  update_songinfo(display, song) unless @stopped
  unless @paused
    display.set_cursor(0,3)
    unless song.time.nil?
      time_display = format('%s/%s',length(song.time.first), length(song.time.last))
      len = 20 - time_display.size
      progress = 'Ð'*(((song.time.first.to_f/song.time.last.to_f)*(len-1)).to_i)
      display.write("#{time_display}#{progress}>")
    end
  end
end

mpd.on :state do |state|
  Thread.abort_on_exception = true
  if state == :stop
    @stopped = true
    display.clear
    display.set_cursor(0,3)
    display.write("#{Time.now.strftime(@config['display']['date_format'])}".center(20))
  end
  if state == :pause
    @paused = true
    @stopped = false
    display.clear_row 3
    display.set_cursor(5, 3)
    display.write('-- PAUSE --')
  end
  if state == :play
    if @stopped
      @last_update = nil
    end
    update_songinfo(display, mpd.current_song)
    display.clear_row 3
    @paused = false
    @stopped = false
  end
end

Signal.trap("TERM") {
  display.disable
  exit
}

Signal.trap("INT") {
  display.disable
  exit
}

Signal.trap("USR1") {
  display.flip
}

while 1
  if @stopped
    display.set_cursor(0,3)
    display.write("#{Time.now.strftime(@config['display']['date_format'])}".center(20))
  end
  sleep 5
end
