# -*- coding : utf-8 -*-
require 'json'
BCDicePATH = "BCDice"

get '/dice' do
  'lingr:DiceBot'
end

GAMELIST = JSON.parse File.read("gameList.json")

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
    game_type = GAMELIST.fetch(command[1], '""')
    `cd #{BCDicePATH}; ruby customDiceBot.rb #{dice_command} #{game_type}`
  }.reject {|result|
    result == "\n"
  }.map {|result|
    "#{u} : #{result.gsub("\n","")}"
  }.join
end
