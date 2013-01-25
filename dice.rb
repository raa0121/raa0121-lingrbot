# -*- coding : utf-8 -*-
require 'json'
BCDicePATH = "BCDice"

get '/dice' do
  'lingr:DiceBot'
end

GAMELIST = File.read("gameList.json")

post '/dice' do
  content_type :text
  json = JSON.parse(request.body.string)
  game_type = '""'

  json["events"].select {|e|
    e["message"]
  }.map {|e|
    m = e["message"]["text"]
    u = e["message"]["nickname"]
    command = m.strip.split(/[\s　]/)
    dice_command = command[0].gsub(">","\\>").gsub("<","\\<").gsub("(","\\(").gsub(")","\\)").gsub("=","\\=")
    gameList = JSON.parse(GAMELIST)
    game_type = gameList.fetch(command[1], '""')
    result = `cd #{BCDicePATH}; ruby customDiceBot.rb #{dice_command} #{game_type}`
    "#{u} : #{result.gsub("\n","")}" unless result == "\n"
  }.join
end
