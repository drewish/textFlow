#!/usr/bin/env ruby

# Copyright 2008, 2009 Andrew Morton <drewish@katherinehouse.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


begin;
  require 'rubygems'
  require 'osax'
  require 'appscript'
  require 'curses'
  rescue LoadError;
end
include Appscript
include OSAX

# Little helper to replicate ncurses' function to move and print a string.
def mvaddstr y, x, str
  Curses.stdscr.setpos y, x
  Curses.stdscr.addstr str
end

begin
  # initialize curses
  Curses.init_screen
  Curses.cbreak           # provide unbuffered input
  Curses.noecho           # turn off input echoing
  Curses.nonl             # turn off newline translation

  Curses.stdscr.keypad(true)     # turn on keypad mode

  mvaddstr(0, 0, 'Loading iTunes...')
  it = app('iTunes')
  mvaddstr(1, 0, 'Reading first track...')

  # If iTunes hasn't played anything since starting then current_track won't be
  # defined. To avoid this we can start and the stop the player.
  if it.player_state.get == :stopped
    it.play
    it.pause
  end
  lastTrackId = nil

  # Main loop.
  begin
    artWidth = 0
    begin
      # Check if the track has changed and update the display.
      if lastTrackId != it.current_track.database_ID.get
        lastTrackId = it.current_track.database_ID.get
        Curses.stdscr.clear

        # Convert the album art into ascii and dump it to the screen.
        if it.current_track.artworks.get.length > 0
          cmd = 'convert - -contrast-stretch 5%x2% jpg:- | jp2a --height=' + (Curses.lines()).to_s + ' -'
          IO.popen(cmd, 'r+') do |pipe|
            pipe << it.current_track.artworks.first.get.raw_data.get.data
            pipe.close_write
            ascii = pipe.readlines
            ascii.each_index {|i|
              mvaddstr(i, 0, ascii[i])
            }
            artWidth = ascii.first.length
          end
        end

        mvaddstr(Curses.lines() / 2 + 0, artWidth + 2, it.current_track.artist.get)
        mvaddstr(Curses.lines() / 2 + 1, artWidth + 2, it.current_track.name.get)
        Curses.refresh
      end
    # Generally the CommandError is thrown when there's not a current track.
    rescue CommandError
      Curses.stdscr.clear
      mvaddstr(Curses.lines() / 2, artWidth + 2, 'Nothing playing.')
      Curses.refresh
      lastTrackId = nil
    end

    # Wait for keyboard input for half a second then give up so we can check
    # if the track has changed.
    if IO.select([STDIN], nil, nil, 0.5)
      ch = Curses.stdscr.getch()
      case(ch)
      when ?\                then it.playpause
      when Curses::KEY_RIGHT then it.next_track
      when Curses::KEY_LEFT  then it.previous_track
      when Curses::KEY_UP    then osax.set_volume(:output_volume => 100)
      when Curses::KEY_DOWN  then osax.set_volume(:output_volume => 0)
      when 'q'[0], 'Q'[0]    then exit
      # For debugging it can be helpful to see the character:
      # else mvaddstr(3, 0, ch.to_s)
      end
    end
  end while true

ensure
  Curses.echo
  Curses.nocbreak
  Curses.nl
  Curses.close_screen
end
