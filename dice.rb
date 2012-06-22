require 'json'

get '/dice' do
	'lingr:DiceBot'
end
post '/dice' do
  content_type :text
  json = JSON.parse(request.body.string)
  tmp = []
  sum = 0
  json["events"].map do |e|
    if e["message"]
      m = e["message"]["text"]
      u = e["message"]["nickname"]
      if /^(\d+)d(\d+)/ =~ m
        n = $1.to_i
        f = $2.to_i
        if n < 256
          n.times do |i| 
            tmp[i] = rand(f)+1
            sum += tmp[i]
          end
          "#{u} : #{n}d#{f}(#{tmp.join(",")})=> #{sum}"
        end
      end
      
      if /^hi\b/ =~ m
        "hi, #{u}"
      end
    end
  end
end
