#!/usr/bin/ruby
# -*- coding utf-8 -*-
require 'sinatra'
require "mechanize"
require 'rexml/document'
require 'digest/md5'
require 'dm-core'
require 'dm-migrations'

load './gyazo.rb'


class GyazoCache
  include DataMapper::Resource
  property :id, Serial
  property :image_url, String, :length => 256
  property :gyazo_url, String, :length => 256
end

DataMapper.finalize

configure :production do
  DataMapper.setup(:default, ENV["HEROKU_POSTGRESQL_PURPLE_URL"])
  GyazoCache.auto_upgrade!
end

configure :test, :development do
  DataMapper.setup(:default, "yaml:///tmp/thumb")
  GyazoCache.auto_upgrade!
end

class Nicothumb
  def initialize
    @agent = Mechanize.new
  end

  def create_gyazo(greatest_url, referer = nil)
    greatest_url =~ /(jpe?g|gif|png)$/
    ext = $1
    temp_file = "tmpimage_#{Time.now.to_i}.#{ext}"
    referer ||= greatest_url.gsub(/(http:\/\/[^\/]+\/).*$/, '\1')
    @agent.get(greatest_url, nil, referer, nil).save("./#{temp_file}")
    gyazo = Gyazo.new ""
    url = gyazo.upload "#{temp_file}"
    File.delete(temp_file)
    "#{url.sub("//","//cache.")}"
  end

  def get_pixiv_image_url(message, params)
    if (not params['id'].nil?) and (not params['id'].empty?)
      @agent.get("http://www.pixiv.net/member.php?id=#{params['id']}")
      name = @agent.page.at('h1.name').content
      pixiv = @agent.page.at('img.user-image').attributes["src"].value
      { :mode => :gyazo, :url => pixiv, :pre_text => name }
    elsif (not params['mode'].nil?) and (not params['mode'].empty?)
      @agent.get(message)
      case params['mode']
      when 'medium', 'big'
        pixiv = @agent.page.at('a.medium-image').children[0].attributes["src"].value
      when 'manga'
        pixiv = @agent.page.parser.xpath('//img[@data-filter="manga-image"]')[0].attributes["data-src"].value
      when 'manga_big'
        pixiv = @agent.page.parser.xpath("//img[@data-filter='manga-image' and @data-index='#{params['page']}']")[0].attributes["data-src"].value
      end
      if not pixiv.nil?
        { :mode => :gyazo, :url => pixiv }
      end
    end
  end

  def get_image_url(message)
    if /^http:\/\/(?:www.)?nico(?:.ms\/|video.jp\/watch\/)((?:nm|sm)?\d+)/ =~ message
      html = @agent.get("http://ext.nicovideo.jp/api/getthumbinfo/#{$1}")
      return unless html
      info = REXML::Document.new html.body
      return unless info.elements['nicovideo_thumb_response']
      thumb_url = info.elements['nicovideo_thumb_response/thumb/thumbnail_url'].text
      begin
        @agent.get(thumb_url +".L")
      rescue Mechanize::ResponseCodeError => ex
        case ex.response_code
        when '404'
          "#{thumb_url}"
        end
      else
        thumb_url += ".L"
      end
      "#{thumb_url}"
    elsif %r|^http://live\.nicovideo\.jp/gate/.*| =~ message
      @agent.get(message)
      "http://live.nicovideo.jp/#{@agent.page.at('div.bn/img')['src']}"
    elsif /^http:\/\/www\.pixiv\.net\/member_illust.php\?(.+)/ =~ message
      params = {}
      $1.split('&').each do |p|
        key, value = p.split('=')
        params[key] = value
      end
      get_pixiv_image_url(message, params)
    elsif %r#http://img\d+\.blogs\.yahoo\.co\.jp/.+/folder/\d+/img_\d+_\d+_\d+# =~ message
      { :mode => :gyazo, :url => message }
#    elsif %r#http://(.+\.fc2\.com)/.+\.(jpe?g|gif|png)$# =~ message
#      { :mode => :gyazo, :url => message }
    elsif %r#http://stat\.ameba\.jp/user_images/.+\.(jpe?g|gif|png)$# =~ message
      { :mode => :gyazo, :url => message, :referer => 'http://ameblo.jp/' }
    elsif /^http:\/\/twitpic\.com\/[0-9a-z]+/ =~ message
      begin
        @agent.get("#{$&}/full")
        @agent.page.parser.xpath("//div[@id='media-full']/img").first.attributes["src"].value
      rescue Mechanize::ResponseCodeError => ex
        case ex.response_code
        when '404'
          return ""
        end
      end
    elsif /^http:\/\/seiga.nicovideo.jp\/seiga\/im(\d+)/ =~ message
      "http://lohas.nicoseiga.jp/thumb/#{$1}i"
    elsif /^http:\/\/seiga.nicovideo.jp\/watch\/mg(\d+)/ =~ message
      @agent.ssl_version = 'SSLv3'
      secure_url = 'https://secure.nicovideo.jp/secure/login?site=niconico'
      @agent.post(secure_url, 'mail' => ENV['NICO_ID'], 'password' => ENV['NICO_PASS'])
      html = @agent.get("http://seiga.nicovideo.jp/api/theme/data?theme_id=#{$1}")
      info = REXML::Document.new html.body
      info.root
      "#{info.elements['response/image_list/image/source_url'].text}#.jpg"
    elsif /^https:\/\/twitter.com\/.+\/status\/\d+/ =~ message
      begin
        @agent.user_agent = "Mozilla/5.0 (Windows NT 6.2; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0"
        @agent.get(message)
        unless @agent.page.parser.xpath("//a[contains(@class, 'media-thumbnail')]").at("img")
          return ""
        end
        @agent.page.parser.xpath("//a[contains(@class, 'media-thumbnail')]").at("img").first[1]
      rescue Mechanize::ResponseCodeError => ex
        case ex.response_code
        when '404'
          return ""
        end
      end
    elsif /^[a-zA-Z0-9_.-]+@([a-zA-Z0-9-]+\.)+[a-zA-Z]+$/ =~ message # mail address
      # Gravatar returns a default icon if not found
      "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(message)}?size=210"
    end
  end

  def append_image_extension(url)
    if url == ""  
      return ""
    elsif url =~ /\.(png|gif|jpg|jpeg)$/
      url
    else
      "#{url}#.jpg"
    end
  end

  def do_maji_sugoi(message)
    result = get_image_url(message)
    if result.kind_of?(Hash) and result[:mode] == :gyazo
      if result[:pre_text].nil?
        pre_text = ""
      else
        pre_text = "#{result[:pre_text]}\n"
      end
      if result[:post_text].nil?
        post_text = ""
      else
        post_text = "\n#{result[:post_text]}"
      end
      cache = GyazoCache.first({:image_url => result[:url]})
      if cache.nil?
        gyazo_url = create_gyazo(result[:url], result[:referer])
        cache = GyazoCache.create(:image_url => result[:url], :gyazo_url => gyazo_url)
      end
      "#{pre_text}#{append_image_extension(cache.gyazo_url)}#{post_text}"
    elsif result.kind_of?(String)
      append_image_extension(result)
    end
  end
end

get '/nicothumb' do
  content_type :text
  "thumb"
end

post '/nicothumb' do
  content_type :text
  json = JSON.parse(request.body.read)
  if not json["events"].nil?
    json["events"].map do |e|
      if e["message"]
        thumb = Nicothumb.new
        res = thumb.do_maji_sugoi(e["message"]["text"])
        (res.nil? or res.empty?) ? "\n" : res
      end
    end
  end
end


times in msec
 clock   self+sourced   self:  sourced script
 clock   elapsed:              other lines

000.015  000.015: --- VIM STARTING ---
000.245  000.230: Allocated generic buffers
000.448  000.203: locale set
000.498  000.050: GUI prepared
000.504  000.006: clipboard setup
000.522  000.018: window checked
007.196  006.674: inits 1
007.221  000.025: parsing arguments
007.223  000.002: expanding arguments
007.302  000.079: shell init
008.026  000.724: Termcap init
008.151  000.125: inits 2
008.407  000.256: init highlight
009.977  000.860  000.860: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/colors/elflord.vim
011.611  000.590  000.590: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/syntax/syncolor.vim
012.584  000.525  000.525: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/syntax/syncolor.vim
012.874  002.378  001.263: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/colors/elflord.vim
013.199  002.889  000.511: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/syntax/synload.vim
084.073  070.705  070.705: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/filetype.vim
084.278  074.159  000.565: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/syntax/syntax.vim
111.712  003.246  003.246: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/ftoff.vim
115.080  000.932  000.932: sourcing /home/raa0121/.vim/neobundle.vim.git/autoload/neobundle/util.vim
116.897  003.246  002.314: sourcing /home/raa0121/.vim/neobundle.vim.git/autoload/neobundle.vim
117.867  000.559  000.559: sourcing /home/raa0121/.vim/neobundle.vim.git/autoload/neobundle/init.vim
120.213  001.451  001.451: sourcing /home/raa0121/.vim/neobundle.vim.git/autoload/neobundle/config.vim
120.478  000.058  000.058: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/ftoff.vim
121.583  000.548  000.548: sourcing /home/raa0121/.vim/neobundle.vim.git/autoload/neobundle/autoload.vim
122.850  000.758  000.758: sourcing /home/raa0121/.vim/neobundle.vim.git/autoload/neobundle/parser.vim
124.793  000.563  000.563: sourcing /home/raa0121/.vim/neobundle.vim.git/autoload/neobundle/types/git.vim
125.579  000.358  000.358: sourcing /home/raa0121/.vim/neobundle.vim.git/autoload/neobundle/types/hg.vim
126.227  000.240  000.240: sourcing /home/raa0121/.vim/neobundle.vim.git/autoload/neobundle/types/nosync.vim
127.075  000.449  000.449: sourcing /home/raa0121/.vim/neobundle.vim.git/autoload/neobundle/types/raw.vim
127.877  000.325  000.325: sourcing /home/raa0121/.vim/neobundle.vim.git/autoload/neobundle/types/svn.vim
156.230  000.160  000.160: sourcing /home/raa0121/.bundle/vim-golang/ftdetect/gofiletype.vim
175.404  002.336  002.336: sourcing /home/raa0121/.vim/neobundle.vim.git/autoload/neobundle/installer.vim
221.926  000.071  000.071: sourcing /home/raa0121/.bundle/neosnippet/ftdetect/neosnippet.vim
232.706  000.055  000.055: sourcing /home/raa0121/.bundle/neosnippet/ftdetect/neosnippet.vim
233.830  000.859  000.859: sourcing /home/raa0121/.bundle/neosnippet/plugin/neosnippet.vim
250.279  000.072  000.072: sourcing /home/raa0121/.bundle/vim-ft-clojure/ftdetect/clojure.vim
276.040  000.068  000.068: sourcing /home/raa0121/.bundle/vim2hs/ftdetect/cabalconfig.vim
276.198  000.041  000.041: sourcing /home/raa0121/.bundle/vim2hs/ftdetect/heist.vim
276.321  000.035  000.035: sourcing /home/raa0121/.bundle/vim2hs/ftdetect/hsc.vim
276.441  000.035  000.035: sourcing /home/raa0121/.bundle/vim2hs/ftdetect/jmacro.vim
310.417  000.062  000.062: sourcing /home/raa0121/.bundle/vim-orgmode/ftdetect/org.vim
342.130  000.555  000.555: sourcing /home/raa0121/.bundle/vim-prettyprint/plugin/prettyprint.vim
416.397  000.376  000.376: sourcing /home/raa0121/.bundle/neosnippet/ftdetect/neosnippet.vim
417.547  000.412  000.412: sourcing /home/raa0121/.vim/neobundle.vim.git/ftdetect/vimrecipe.vim
418.085  074.364  073.576: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/filetype.vim
418.836  000.152  000.152: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/ftplugin.vim
419.533  000.117  000.117: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/indent.vim
421.021  001.095  001.095: sourcing /home/raa0121/.bundle/vim-singleton/autoload/singleton.vim
425.617  416.861  249.964: sourcing $HOME/.vimrc
425.678  000.410: sourcing vimrc file(s)
426.938  000.891  000.891: sourcing /home/raa0121/.bundle/calendar.vim/plugin/calendar.vim
431.204  003.830  003.830: sourcing /home/raa0121/.bundle/qfixhowm/plugin/env-cnv.vim
433.825  002.511  002.511: sourcing /home/raa0121/.bundle/qfixhowm/plugin/mygrep.vim
438.644  004.688  004.688: sourcing /home/raa0121/.bundle/qfixhowm/plugin/myqfix.vim
443.181  004.383  004.383: sourcing /home/raa0121/.bundle/qfixhowm/plugin/qfixmemo.vim
446.048  002.692  002.692: sourcing /home/raa0121/.bundle/qfixhowm/plugin/qfixmru.vim
447.066  000.571  000.571: sourcing /home/raa0121/.bundle/vim-marching/plugin/marching.vim
447.875  000.229  000.229: sourcing /home/raa0121/.bundle/neocomplete.vim/plugin/neocomplete/buffer.vim
448.128  000.169  000.169: sourcing /home/raa0121/.bundle/neocomplete.vim/plugin/neocomplete/dictionary.vim
448.369  000.175  000.175: sourcing /home/raa0121/.bundle/neocomplete.vim/plugin/neocomplete/include.vim
448.613  000.182  000.182: sourcing /home/raa0121/.bundle/neocomplete.vim/plugin/neocomplete/syntax.vim
448.855  000.174  000.174: sourcing /home/raa0121/.bundle/neocomplete.vim/plugin/neocomplete/tag.vim
449.360  000.445  000.445: sourcing /home/raa0121/.bundle/neocomplete.vim/plugin/neocomplete.vim
449.903  000.338  000.338: sourcing /home/raa0121/.bundle/vimproc/plugin/vimproc.vim
450.146  000.059  000.059: sourcing /home/raa0121/.bundle/neosnippet/plugin/neosnippet.vim
451.039  000.671  000.671: sourcing /home/raa0121/.bundle/sudo.vim/plugin/sudo.vim
451.755  000.404  000.404: sourcing /home/raa0121/.bundle/vim-ref/plugin/ref.vim
452.567  000.479  000.479: sourcing /home/raa0121/.bundle/vim-splash/plugin/splash.vim
453.467  000.604  000.604: sourcing /home/raa0121/.bundle/sonictemplate-vim/plugin/sonictemplate.vim
453.743  000.037  000.037: sourcing /home/raa0121/.bundle/vim-prettyprint/plugin/prettyprint.vim
454.539  000.589  000.589: sourcing /home/raa0121/.bundle/vimconsole.vim/plugin/vimconsole.vim
455.571  000.271  000.271: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/plugin/getscriptPlugin.vim
456.562  000.914  000.914: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/plugin/gzip.vim
457.423  000.696  000.696: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/plugin/matchparen.vim
459.160  001.643  001.643: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/plugin/netrwPlugin.vim
459.555  000.166  000.166: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/plugin/rrhelper.vim
459.777  000.119  000.119: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/plugin/spellfile.vim
460.786  000.919  000.919: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/plugin/tarPlugin.vim
461.332  000.351  000.351: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/plugin/tohtml.vim
461.973  000.541  000.541: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/plugin/vimballPlugin.vim
462.977  000.872  000.872: sourcing /home/raa0121/.vimenv/versions/vim7.4.131/share/vim/vim74/plugin/zipPlugin.vim
463.672  000.244  000.244: sourcing /home/raa0121/.vim/neobundle.vim.git/plugin/neobundle.vim
463.750  007.215: loading plugins
463.778  000.028: inits 3
464.300  000.522: reading viminfo
464.323  000.023: setup clipboard
464.420  000.097: setting raw mode
464.424  000.004: start termcap
464.549  000.125: clearing screen
465.544  000.995: opening buffers
468.483  001.649  001.649: sourcing /home/raa0121/.bundle/vim-openbuf/autoload/openbuf.vim
469.875  002.682: BufEnter autocommands
469.896  000.021: editing files in windows
474.286  000.471  000.471: sourcing /home/raa0121/.bundle/vim-splash/autoload/splash.vim
1624.601  1154.234: VimEnter autocommands
1624.817  000.216: before starting main loop
1626.984  002.167: first screen update
1626.997  000.013: --- VIM STARTED ---
