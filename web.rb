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
      if /^(\d+)d(\d+)/ =~ m
        n = $1.to_i
        f = $2.to_i
        if n < 256
          n.times do |i| 
            tmp[i] = rand(-1+f)+1
            sum += tmp[i]
          end
          "(#{tmp.join(",")})=> #{sum}"
        end
      end
    end
  end
end
