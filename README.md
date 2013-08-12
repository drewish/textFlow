# textFlow

textFlow is an ruby script for OS X that talks to iTunes via AppleScript and
converts the current track's album art into ASCII for display in a terminal.

## Requirements

You'll need to use [Homebrew](http://brew.sh/) to install ImageMagick
and jp2a:

    brew install jp2a imagemagick

You'll also need to use Ruby's gem to install and appscript:

    gem install rb-appscript

or

    bundle install

## Operation

Start the program:

    ./textFlow.rb

Then:

- switch between songs with the arrow keys
- pause and play with the spacebar
- quit with `q`

## For more information

See http://drewish.com/node/130 or http://github.com/drewish/textFlow
