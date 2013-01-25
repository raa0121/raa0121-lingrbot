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

  json["events"].map do |e|
    if e["message"]
      m = e["message"]["text"]
      u = e["message"]["nickname"]
      command = m.strip.split(/[\s　]/)
      diceCommand = command[0].gsub(">","\\>").gsub("<","\\<").gsub("(","\\(").gsub(")","\\)").gsub("=","\\=")
      File.open("gameList.json","r"){|gl|
        gameList = JSON.parse(gl.read)
        gameType = gameList.fetch(command[1],"\"\"")
        "#{u} : #{`cd #{BCDicePATH}/src; ruby-1.8 cgiDiceBot.rb #{diceCommand} #{gameType}`}"
      }
    end
  end
end
