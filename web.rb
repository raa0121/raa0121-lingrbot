require 'sinatra'
require 'json'

get '/' do
	'lingr:DiceBot'
end
post '/'do
	json = JSON.parce(parms[:json])
	tmp = ""
	json["events"].each do |e|
	if e["message"]
		m = e["message"]["text"]
		if /^(\d*)d(\d*)/ =~ m
			$1.times do 
				tmp = rand($2.to_i -1)+1
				tmp += " "
			end
		end
	end
	tmp
end
