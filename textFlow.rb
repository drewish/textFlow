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

def init_itunes
  Curses.stdscr.setpos 0, 0
  Curses.stdscr << "Loading iTunes..."

  it = app 'iTunes'
  Curses.stdscr << "\nReading first track..."

  # If iTunes hasn't played anything since starting then current_track won't be
  # defined. To avoid this we can start and the stop the player.
  if it.player_state.get == :stopped
    it.play
    it.pause
  end

  it
end

def ascii_album current_track
  return [] unless current_track.artworks.get.length > 0

  cmd = "convert - -contrast-stretch 5%x2% jpg:- | jp2a --height=#{Curses.lines} -"
  IO.popen(cmd, 'r+') do |pipe|
    pipe << current_track.artworks.first.get.raw_data.get.data
    pipe.close_write
    pipe.readlines
  end
end

def draw_album current_track
  ascii = ascii_album current_track
  ascii.each_index {|i|
    Curses.stdscr.setpos i, 0
    Curses.stdscr << ascii[i]
  }
  ascii.first.length
end

begin
  # initialize curses
  Curses.init_screen
  Curses.cbreak           # provide unbuffered input
  Curses.noecho           # turn off input echoing
  Curses.nonl             # turn off newline translation
  Curses.curs_set 0       # hide the cursor

  Curses.stdscr.keypad true     # turn on keypad mode

  it = init_itunes
  last_track_id = nil

  # Main loop.
  begin
    art_width = 0
    begin
      # Check if the track has changed and update the display.
      if last_track_id != it.current_track.database_ID.get
        last_track_id = it.current_track.database_ID.get
        Curses.stdscr.clear

        # Convert the album art into ascii and dump it to the screen.
        art_width = draw_album it.current_track

        Curses.stdscr.setpos Curses.lines / 2 + 0, art_width + 2
        Curses.stdscr << it.current_track.artist.get

        Curses.stdscr.setpos Curses.lines / 2 + 1, art_width + 2
        Curses.stdscr << it.current_track.name.get
      end
    # Generally the CommandError is thrown when there's not a current track.
    rescue CommandError
      last_track_id = nil
      Curses.stdscr.clear
      Curses.stdscr.setpos Curses.lines / 2 + 0, art_width + 2
      Curses.stdscr << 'Nothing playing.'
    end

    Curses.refresh

    # Wait for keyboard input for half a second then give up so we can check
    # if the track has changed.
    if IO.select [STDIN], nil, nil, 0.5
      ch = Curses.stdscr.getch
      case ch
      when ?\                then it.playpause
      when Curses::KEY_RIGHT then it.next_track
      when Curses::KEY_LEFT  then it.previous_track
      when Curses::KEY_UP    then osax.set_volume output_volume: 100
      when Curses::KEY_DOWN  then osax.set_volume output_volume: 0
      when 'q'[0], 'Q'[0]    then exit
      end
    end
  end while true

# Put everything back when we're done.
ensure
  Curses.echo
  Curses.nocbreak
  Curses.nl
  Curses.curs_set 1
  Curses.close_screen
end