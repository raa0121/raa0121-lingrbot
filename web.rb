require 'sinatra'
require 'json'

get '/' do
	'lingr:DiceBot'
end
post '/'do
  content_type :text
  json = JSON.parse(request.body.string)
  tmp = []
  sum = 0
  json["events"].map do |e|
    #request.env['rack.input'].read
  #end
    if e["message"]
      m = e["message"]["text"]
      if /^(\d*)d(\d*)/ =~ m
        $1.to_i.times do |i| 
          tmp[i] = rand(-1+$2.to_i)+1
          sum += tmp[i]
        end
      end
    end
    "("+ tmp.join(",") + ")=> "+sum
  end
end
