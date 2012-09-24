#$LOAD_PATH << File.dirname(__FILE__) + "/BCDice/src"

require 'rubygems'
require 'sinatra'

get '/' do
  "Here is raa0121's sinatra app"
end

load 'dice.rb'
load 'bot.rb'
