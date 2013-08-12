# textFlow

textFlow is an ruby script for OS X that talks to iTunes via AppleScript and
converts the current track's album art into ASCII for display in a terminal.

## Requirements

You'll need to use MacPorts (http://www.macports.org) to install ImageMagick
and jp2a:
    sudo port install jp2a imagemagick +no_x11

You'll also need to use Ruby's gem to install ncurses and appscript:
    sudo gem install ncurses rb-appscript

## For more information

See http://drewish.com/node/130 or http://github.com/drewish/textFlow