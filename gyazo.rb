require 'net/http'
require 'openssl'
require 'json'

class Gyazo
  attr_reader :id

  def initialize(id = '',
                 boundary = '----BOUNDARYBOUNDARY----',
                 host = 'upload.gyazo.com',
                 cgi = '/upload.cgi',
                 ua = 'Gyazo/1.2')
    @id = id
    @boundary = boundary
    @host = host
    @cgi = cgi
    @ua = ua
  end

  def upload(img_path)
    if !File.exists? img_path
      exit
    end

    img = File.read img_path

    metadata = JSON.generate({
      app: "",
      title: "",
      url: "",
      note: ""
    })

    data = <<EOF
--#{@boundary}\r
content-disposition: form-data; name="metadata"\r
\r
#{metadata}\r
--#{@boundary}\r
content-disposition: form-data; name="id"\r
\r
#{@id}\r
--#{@boundary}\r
content-disposition: form-data; name="imagedata"; filename="gyazo.com"\r
\r
#{img}\r
--#{@boundary}--\r
EOF

    header ={
      'Content-Length' => data.length.to_s,
      'Content-type' => "multipart/form-data; @boundary=#{@boundary}",
      'User-Agent' => @ua
    }

    env = ENV['http_proxy']
    if env then
      uri = URI(env)
      proxy_host, proxy_port = uri.host, uri.port
    else
      proxy_host, proxy_port = nil, nil
    end

    url = ''
    https = Net::HTTP::Proxy(proxy_host, proxy_port).new(HOST, 443)
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_PEER
    https.verify_depth = 5
    https.start{
      res = https.post(@cgi, data, header)
      url = res.response.body
      newid = res.response['X-Gyazo-Id']
      @id = newid if @id == '' and newid and newid != ''
    }

    "#{ url }"
  end
end
