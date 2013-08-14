#!/usr/bin/env ruby

# Copyright 2008, 2009 Andrew Morton <drewish@katherinehouse.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

begin
  require 'rubygems'
  require 'osax'
  require 'appscript'
  require 'curses'
  rescue LoadError;
end
include Appscript
include OSAX
include Curses

def init_itunes
  stdscr.setpos 0, 0
  stdscr << "Loading iTunes..."

  it = app 'iTunes'
  stdscr << "\nReading first track..."

  # If iTunes hasn't played anything since starting then current_track won't be
  # defined. To avoid this we can start and the stop the player.
  if it.player_state.get == :stopped
    it.play
    it.pause
  end

  it
end

def has_art? current_track
  current_track.artworks.get.length > 0
end

# In what ever format it was added to the audio
def art_from current_track
  current_track.artworks.first.get.raw_data.get.data
end

def ascii_album image
  cmd = "convert - -contrast-stretch 5%x2% jpg:- | jp2a --height=#{Curses.lines} -"
  IO.popen(cmd, 'r+') do |pipe|
    pipe << image
    pipe.close_write
    pipe.read
  end
end

def ansi_album image
  cmd = "convert - -contrast-stretch 5%x2% jpg:- | jp2a --height=#{Curses.lines} --color -"
  IO.popen(cmd, 'r+') do |pipe|
    pipe << image
    pipe.close_write
    pipe.read
  end
end

def save_artwork current_track
  image = art_from current_track
  File.open("artwork.txt",'w') do |file|
    file << if has_colors? then
      ansi_album image
    else
      ascii_album image
    end
  end
end

def draw_album current_track
  return 0 unless has_art? current_track

  image = art_from current_track

  stdscr.setpos 0, 0

  if has_colors?
    remaining = ansi = ansi_album image
    stdscr.color_set 0
    begin
      text, code, remaining = remaining.partition(/\e\[\d{1,2}m/)
      stdscr << text if text
      stdscr.color_set code[2..-2].to_i if code
    end until (remaining.empty?)
    ansi.gsub(/\e\[\d{1,2}m/, '').index "\n"
  else
    ascii = ascii_album image
    stdscr << ascii
    ascii.index "\n"
  end
end

begin
  # initialize curses
  init_screen
  if has_colors?
    start_color
    use_default_colors
    [ COLOR_BLACK, COLOR_RED, COLOR_GREEN, COLOR_YELLOW,
      COLOR_BLUE, COLOR_MAGENTA, COLOR_CYAN, COLOR_WHITE
    ].each do |c|
      # Use the ANSI color number as the pair's number.
      init_pair 30 + c, c, -1
    end
  end
  cbreak           # provide unbuffered input
  noecho           # turn off input echoing
  nonl             # turn off newline translation
  curs_set 0       # hide the cursor

  stdscr.keypad true     # turn on keypad mode

  it = init_itunes
  last_track_id = nil

  # Main loop.
  begin
    art_width = 0
    begin
      # Check if the track has changed and update the display.
      if last_track_id != it.current_track.database_ID.get
        last_track_id = it.current_track.database_ID.get
        stdscr.clear

        art_width = draw_album it.current_track

        stdscr.setpos lines / 2 + 0, art_width + 2
        stdscr << it.current_track.artist.get

        stdscr.setpos lines / 2 + 1, art_width + 2
        stdscr << it.current_track.name.get
      end
    # Generally the CommandError is thrown when there's not a current track.
    rescue CommandError
      last_track_id = nil
      stdscr.clear
      stdscr.setpos lines / 2 + 0, art_width + 2
      stdscr << 'Nothing playing.'
    end

    refresh

    # Wait for keyboard input for half a second then give up so we can check
    # if the track has changed.
    if IO.select [STDIN], nil, nil, 0.5
      ch = stdscr.getch
      case ch
      when ?\                then it.playpause
      when Curses::KEY_RIGHT then it.next_track
      when Curses::KEY_LEFT  then it.previous_track
      when Curses::KEY_UP    then osax.set_volume output_volume: 100
      when Curses::KEY_DOWN  then osax.set_volume output_volume: 0
      when 's'[0], 'S'[0]    then save_artwork it.current_track
      when 'q'[0], 'Q'[0]    then exit
      end
    end
  end while true

# Put everything back when we're done.
ensure
  echo
  nocbreak
  nl
  curs_set 1
  close_screen
end