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


# This script requires the appscript and ncurses libraries.
# To install it run: sudo gem install rb-appscript ncurses
#
# You'll also need to have ImageMagick and jp2a installed.
# Use MacPorts: sudo port install jp2a imagemagick

begin;
  require 'rubygems'
  require 'osax'
  require 'appscript'
  require 'ncurses'
  rescue LoadError;
end
include Appscript
include OSAX

begin
  # initialize ncurses
  Ncurses.initscr
  Ncurses.cbreak           # provide unbuffered input
  Ncurses.noecho           # turn off input echoing
  Ncurses.nonl             # turn off newline translation

  Ncurses.stdscr.intrflush(false) # turn off flush-on-interrupt
  Ncurses.stdscr.keypad(true)     # turn on keypad mode

  Ncurses.stdscr.mvaddstr(0, 0, 'Loading iTunes...')
  it = app('iTunes')
  Ncurses.stdscr.mvaddstr(1, 0, 'Reading first track...')

  # If iTunes hasn't played anything since starting current_track won't be
  # defined. To avoid this we can start and the stop the player.
  track = nil
  if it.player_state.get == :stopped
    it.play
    it.pause
  end

  begin

    # Check if the track has changed and udate the display
    if it.current_track.get == nil
      lastTrackId = nil
      Ncurses.stdscr.clear
      Ncurses.stdscr.mvaddstr(0, 0, 'No track selected.')
    elsif lastTrackId != it.current_track.database_ID.get
      lastTrackId = it.current_track.database_ID.get
      Ncurses.stdscr.clear

      # Convert the album art into ascii and dump it to the screen.
      width = 0
      if it.current_track.artworks.get.length > 0
        cmd = 'convert - -contrast-stretch 5%x2% jpg:- | jp2a --height=' + (Ncurses.LINES()).to_s + ' -'
        IO.popen(cmd, 'r+') do |pipe|
          pipe << it.current_track.artworks.first.get.raw_data.get.data
          pipe.close_write
          ascii = pipe.readlines
          ascii.each_index {|i|
            Ncurses.stdscr.mvaddstr(i, 0, ascii[i])
          }
          width = ascii.first.length
        end
      end

      Ncurses.stdscr.mvaddstr(0, width + 2, it.current_track.artist.get)
      Ncurses.stdscr.mvaddstr(1, width + 2, it.current_track.name.get)
      Ncurses.refresh
    end

    if IO.select([STDIN], nil, nil, 0.5)
      ch = Ncurses.stdscr.getch()
      case(ch)
      when ?\ :
        it.playpause
      when Ncurses::KEY_RIGHT :
        it.next_track
      when Ncurses::KEY_LEFT :
        it.previous_track
      when Ncurses::KEY_UP :
        osax.set_volume(:output_volume => 100)
      when Ncurses::KEY_DOWN :
        osax.set_volume(:output_volume => 0)
      when 'q'[0], 'Q'[0] :
        exit
  #    else
  #      Ncurses.stdscr.mvaddstr(3, 0, ch.to_s)
      end
    end
  end while true

ensure
  Ncurses.echo
  Ncurses.nocbreak
  Ncurses.nl
  Ncurses.endwin
end
