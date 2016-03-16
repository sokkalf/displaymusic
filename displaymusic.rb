require 'oled-control/oled'
require 'ruby-mpd'
require 'yaml'
require 'socket'

class String
  def fix(size, padstr=' ')
    self[0...size].ljust(size, padstr) #or ljust
  end
end
@config = YAML.load_file('config.yml')

if @config['options']['show_ip_address']
  @ip_address = Socket.ip_address_list.select{|i| !i.ipv4_loopback? and i.ipv4_private? }.first.ip_address
end

display = OLED.new(@config['display']['i2c-bus'], @config['display']['i2c-address'],
                   @config['display']['flipped'])
display.set_contrast(@config['display']['contrast'])

mpd = MPD.new @config['mpd']['host'], @config['mpd']['port'], {callbacks: true}

display.create_character(1, [0b11000,
                             0b11100,
                             0b11110,
                             0b11111,
                             0b11110,
                             0b11100,
                             0b11000,
                             0b00000])

display.create_character(2, [0b00000,
                             0b11011,
                             0b11011,
                             0b11011,
                             0b11011,
                             0b11011,
                             0b11011,
                             0b00000])

display.create_character(3, [0b11111,
                             0b11111,
                             0b11111,
                             0b11111,
                             0b11111,
                             0b11111,
                             0b11111,
                             0b11111])
# "splash" screen
display.set_cursor(0,0)
display.write("   \x03\x03\x03   \x03\x03   \x03\x03\x03      \x03  \x03 \x03  \x03 \x03         \x03  \x03 \x03\x03\x03\x03 \x03         \x03\x03\x03  \x03  \x03  \x03\x03\x03   ")
sleep 5

mpd.connect

def format_string(song)
  year = if song.date.nil?
           ""
         else
           "#{song.date}Ý"
         end
  #                                   take advantage of that Ý is a small dot in the OLED charset
  format('%s%s%s', song.title.fix(20), song.artist.fix(20), "#{year}#{song.album}".fix(20))
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
  unless song.nil?
    update_songinfo(display, song) unless @stopped
    unless @paused
      display.set_cursor(0, 3)
      unless song.time.nil?
        time_display = format('%s/%s', length(song.time.first), length(song.time.last))
        len = 20 - time_display.size
        progress = 'Ð'*(((song.time.first.to_f/song.time.last.to_f)*(len-1)).to_i)
        display.write("#{time_display}#{progress}\x01")
      end
    end
  end
end

mpd.on :state do |state|
  Thread.abort_on_exception = true
  if state == :stop
    @stopped = true
    display.clear
    display.set_cursor(0,3)
    display.write("#{Time.now.strftime(@config['options']['date_format'])}".center(20))
  end
  if state == :pause
    @paused = true
    @stopped = false
    display.clear_row 3
    display.set_cursor(0, 3)
    display.write("PAUSE \x02".center(20))
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
    if @config['options']['show_ip_address']
      display.set_cursor(0,1)
      display.write(@ip_address.center(20))
    end
    display.set_cursor(0,3)
    display.write("#{Time.now.strftime(@config['options']['date_format'])}".center(20))
  end
  sleep 5
end
