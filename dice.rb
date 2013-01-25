# -*- coding : utf-8 -*-
require 'json'
BCDicePATH = "BCDice"

get '/dice' do
  'lingr:DiceBot'
end

post '/dice' do
  content_type :text
  json = JSON.parse(request.body.string)
  gameType = "\"\""

  json["events"].select {|e|
    e["message"]
  }.map {|e|
      m = e["message"]["text"]
      u = e["message"]["nickname"]
      command = m.strip.split(/[\s　]/)
      diceCommand = command[0].gsub(">","\\>").gsub("<","\\<").gsub("(","\\(").gsub(")","\\)").gsub("=","\\=")
      File.open("gameList.json","r"){|gl|
        gameList = JSON.parse(gl.read)
        gameType = gameList.fetch(command[1],"\"\"")
        result = `cd #{BCDicePATH}; ruby customDiceBot.rb #{diceCommand} #{gameType}`
        "#{u} : #{result.gsub("\n","")}" unless result == "\n"
      }
  }.join
end
