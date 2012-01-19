require 'sinatra'
require 'json'

get '/' do
	'lingr:DiceBot'
end
post '/'do
	json = JSON.parse(request.env['rack.input'].read)
	tmp = []
	json["events"].each do |e|
		request.env['rack.input'].read
	#if e["message"]
	#	m = e["message"]["text"]
	#	if /^(\d*)d(\d*)/ =~ m
	#		$1.to_i.times do |i| 
	#			tmp[i] = rand($2.to_i -1)+1
	#		end
	#	end
	#end
	#tmp.join ","
end
