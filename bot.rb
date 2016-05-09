require 'json'
require 'prime'

get '/ruby' do
  "lingr:RubyBot"
end

post '/ruby' do
  content_type :text
  json = JSON.parse(request.body.read)
  json["events"].map do |e|
    @m = e["message"]
    if @m
      t = @m["text"]
      if /^!(c)?ruby\s+(.*)/m =~ t
        after = eval "#{$2}"
        return "#{after}"
      end
    end
  end
end
