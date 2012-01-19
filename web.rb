require 'sinatra'
require "json"
require "cgi"

json = JSON.parse(CGI.new["json"])

print "Content-Type: text/plain\n\n"
get '/' do
	if /(^d*)d(^d*)/ =~ json["events"]["message"]["text"] do
		$1.times do
				print rand($2-1)+1
	end
end
