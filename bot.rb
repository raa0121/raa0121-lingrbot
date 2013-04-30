require 'json'
require 'prime'

get '/ruby' do
  "lingr:RubyBot"
end

post '/ruby' do
  content_type :text
  json = JSON.parse(request.body.string)
  json["events"].map do |e|
    if e["message"]
      m = e["message"]["text"]
      if /^!(c)?ruby\s+(.*)/m =~ m
        #x = Thread.start do
        $SAFE = 2
        after = eval "#{$1}"
        return "#{after}"
        #end
        #  "#{x.value}"
          #sandbox{$1}
      end
    end
  end
end
