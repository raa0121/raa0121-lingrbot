ENV['RACK_ENV'] = 'test'

require './nicothumb'
require 'rspec'
require 'rack/test'
require 'json'

describe 'The Thumb' do
  before(:each) do
    @thumb = Nicothumb.new
  end

  describe 'pixiv' do
    context 'user illust list' do
      subject { @thumb.get_image_url('http://www.pixiv.net/member_illust.php?id=747452') }
      it { should be_a_kind_of(Hash) }
      it { should include(:mode => :gyazo) }
      it { should have_key(:url) }
      it { should have_key(:pre_text) }
    end

    context 'illust medium' do
      subject { @thumb.get_image_url('http://www.pixiv.net/member_illust.php?mode=medium&illust_id=37361700') }
      it { should be_a_kind_of(Hash) }
      it { should include(:mode => :gyazo) }
      it { should have_key(:url) }
    end

    context 'illust big' do
      subject { @thumb.get_image_url('http://www.pixiv.net/member_illust.php?mode=big&illust_id=37361700') }
      it { should be_a_kind_of(Hash) }
      it { should include(:mode => :gyazo) }
      it { should have_key(:url) }
    end

    context 'illust medium (manga)' do
      subject { @thumb.get_image_url('http://www.pixiv.net/member_illust.php?mode=medium&illust_id=37979251') }
      it { should be_a_kind_of(Hash) }
      it { should include(:mode => :gyazo) }
      it { should have_key(:url) }
    end

    context 'illust manga' do
      subject { @thumb.get_image_url('http://www.pixiv.net/member_illust.php?mode=manga&illust_id=37979251') }
      it { should be_a_kind_of(Hash) }
      it { should include(:mode => :gyazo) }
      it { should have_key(:url) }
    end

    context 'illust manga big' do
      subject { @thumb.get_image_url('http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id=37979251&page=5') }
      it { should be_a_kind_of(Hash) }
      it { should include(:mode => :gyazo) }
      it { should have_key(:url) }
    end
  end

  describe 'nicovideo' do
    subject { @thumb.get_image_url('http://www.nicovideo.jp/watch/sm9') }
    it { should be_a_kind_of(String) }
  end

  describe 'Twitpic' do
    subject { @thumb.get_image_url('http://twitpic.com/cvze6i') }
    it { should be_a_kind_of(String) }
  end

  describe 'seiga.nicovideo' do
    subject { @thumb.get_image_url('http://seiga.nicovideo.jp/seiga/im1667353') }
    it { should be_a_kind_of(String) }
  end

  describe 'seiga.nicovideo.manga' do
    subject { @thumb.get_image_url('http://seiga.nicovideo.jp/watch/mg46919') }
    it { should be_a_kind_of(String) }
  end

  describe 'pic.twitter.com' do
    subject { @thumb.get_image_url('https://twitter.com/sora_h/status/317900657661194240/photo/1') }
    it { should be_a_kind_of(String) }
  end

  describe 'instagram.com' do
    subject { @thumb.get_image_url('http://instagram.com/p/Qu0-boxInJ/') }
    it { should be_a_kind_of(String) }
    it { should match(/^http:\/\/[^\/]+instagram\.com\/.+$/) }
    it { should_not match(/^http:\/\/[^\/]+instagram\.com\/.+$\n^with video$/m) }
  end

  describe 'instagram.com with video' do
    subject { @thumb.get_image_url('http://instagram.com/p/muadXDxIiq/') }
    it { should be_a_kind_of(String) }
    it { should match(/^http:\/\/[^\/]+instagram\.com\/.+$\n^with video$/m) }
  end

  describe 'Gravatar' do
    context 'exist' do
      subject { @thumb.get_image_url('unmoremaster@gmail.com') }
      it { should be_a_kind_of(String) }
      it { should_not be_empty }
    end

    context 'not found' do
      subject { @thumb.get_image_url('unko@ibm.com') }
      it { should be_a_kind_of(String) }
      it { should_not be_empty }
    end
  end

  describe 'ameba blog' do
    before do
      @url = 'http://stat.ameba.jp/user_images/20130816/13/nakagawa-shoko/9e/46/j/o0321042712649574460.jpg'
    end
    subject { @thumb.get_image_url(@url) }
    it { should be_a_kind_of(Hash) }
    it { should include(:mode => :gyazo, :url => @url, :referer => 'http://ameblo.jp/') }
  end

  describe 'sugoi' do
    context 'ameba blog with Gyazo' do
      subject { @thumb.do_maji_sugoi('http://stat.ameba.jp/user_images/20130816/13/nakagawa-shoko/9e/46/j/o0321042712649574460.jpg') }
      it { should be_a_kind_of(String) }
      it { should match(/^http:\/\/i\.[^\/]+\/.+\.jpg$/) }
    end

    context 'user illust list with Gyazo' do
      subject { @thumb.do_maji_sugoi('http://www.pixiv.net/member_illust.php?id=747452') }
      it { should be_a_kind_of(String) }
      it { should match(/^.*\nhttp:\/\/i\.[^\/]+\/.+\.jpg$/) }
    end

    context 'illust medium with Gyazo' do
      subject { @thumb.do_maji_sugoi('http://www.pixiv.net/member_illust.php?mode=medium&illust_id=37361700') }
      it { should be_a_kind_of(String) }
      it { should match(/http:\/\/i\.[^\/]+\/.+\.png$/) }
    end
  end

  describe 'Yahoo!' do
    context 'blog old' do
      before do
        @url = 'http://img2.blogs.yahoo.co.jp/ybi/1/1f/99/ywmjr369/folder/624206/img_624206_55199187_0'
      end
      subject { @thumb.get_image_url(@url) }
      it { should be_a_kind_of(Hash) }
      it { should include(:mode => :gyazo, :url => @url) }
    end

    context 'blog' do
      before do
        @url = 'http://blogs.c.yimg.jp/res/blog-1f-99/ywmjr369/folder/624206/87/55199187/img_0'
      end
      subject { @thumb.get_image_url(@url) }
      it { should be_a_kind_of(String) }
      it { should ==('http://blogs.c.yimg.jp/res/blog-1f-99/ywmjr369/folder/624206/87/55199187/img_0#.png') }
    end

    context 'ks' do
      before do
        @url = 'http://ks.c.yimg.jp/res/chie-ans-327/327/846/890/i320'
      end
      subject { @thumb.get_image_url(@url) }
      it { should be_a_kind_of(String) }
      it { should ==('http://ks.c.yimg.jp/res/chie-ans-327/327/846/890/i320#.png') }
    end
  end

  describe 'Gyazo direct link' do
    subject { @thumb.get_image_url('http://gyazo.com/cdb44db0ac247b3c01137d93ce297392') }
    it { should be_a_kind_of(String) }
    it { should ==('http://i.gyazo.com/cdb44db0ac247b3c01137d93ce297392.jpg') }
  end
end

describe 'The Thumb Rack test' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  describe 'Yahoo!' do
    context 'blog old' do
      it do
        body = { "events" => [ { "message" => { "text" => 'http://img2.blogs.yahoo.co.jp/ybi/1/1f/99/ywmjr369/folder/624206/img_624206_55199187_0' } } ] }
        post '/nicothumb', body.to_json.to_s
        last_response.should be_ok
        last_response.body.should match(/^http:\/\/i\.[^\/]+\/.+\.jpg$/)
      end
    end

    context 'blog' do
      it do
        body = { "events" => [ { "message" => { "text" => 'http://blogs.c.yimg.jp/res/blog-1f-99/ywmjr369/folder/624206/87/55199187/img_0' } } ] }
        post '/nicothumb', body.to_json.to_s
        last_response.should be_ok
        last_response.body.should ==('http://blogs.c.yimg.jp/res/blog-1f-99/ywmjr369/folder/624206/87/55199187/img_0#.png')
      end
    end

    context 'ks' do
      it do
        body = { "events" => [ { "message" => { "text" => 'http://ks.c.yimg.jp/res/chie-ans-327/327/846/890/i320' } } ] }
        post '/nicothumb', body.to_json.to_s
        last_response.should be_ok
        last_response.body.should ==('http://ks.c.yimg.jp/res/chie-ans-327/327/846/890/i320#.png')
      end
    end
  end

=begin
  context 'FC2' do
    it do
      body = { "events" => [ { "message" => { "text" => 'http://blog-imgs-36-origin.fc2.com/n/o/n/nonor/congenitalesotropia.jpg' } } ] }
      post '/nicothumb', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should match(/^http:\/\/i\.[^\/]+\/.+\.png$/)
    end
  end
=end

  context 'seiga.nicovideo' do
    it do
      body = { "events" => [ { "message" => { "text" => 'http://seiga.nicovideo.jp/seiga/im1667353' } } ] }
      post '/nicothumb', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should match(/^http:\/\/lohas.nicoseiga.jp\/.*$/)
    end
  end

  context 'seiga.nicovideo.manga' do
    it do
      body = { "events" => [ { "message" => { "text" => 'http://seiga.nicovideo.jp/watch/mg46919' } } ] }
      post '/nicothumb', body.to_json.to_s
      last_response.should be_ok
    end
  end

  context 'instagram.com' do
    it do
      body = { "events" => [ { "message" => { "text" => 'http://instagram.com/p/Qu0-boxInJ/' } } ] }
      post '/nicothumb', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should match(/^http:\/\/[^\/]+instagram\.com\/.+$/)
      last_response.body.should_not match(/^http:\/\/[^\/]+instagram\.com\/.+$\n^with video$/m)
    end
  end

  context 'instagram.com with video' do
    it do
      body = { "events" => [ { "message" => { "text" => 'http://instagram.com/p/muadXDxIiq/' } } ] }
      post '/nicothumb', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should match(/^http:\/\/[^\/]+instagram\.com\/.+$\n^with video$/m)
    end
  end

  describe 'pixiv' do
    context 'user illust list' do
      it do
        body = { "events" => [ { "message" => { "text" => 'http://www.pixiv.net/member_illust.php?id=747452' } } ] }
        post '/nicothumb', body.to_json.to_s
        last_response.should be_ok
        last_response.body.should match(/^.*\nhttp:\/\/i\.[^\/]+\/.+\.jpg$/)
      end
    end

    context 'illust medium' do
      it do
        body = { "events" => [ { "message" => { "text" => 'http://www.pixiv.net/member_illust.php?mode=medium&illust_id=35524272' } } ] }
        post '/nicothumb', body.to_json.to_s
        last_response.should be_ok
        last_response.body.should be_a_kind_of(String)
      end
    end

    context 'illust medium cache' do
      it do
        body = { "events" => [ { "message" => { "text" => 'http://www.pixiv.net/member_illust.php?mode=medium&illust_id=188556' } } ] }
        post '/nicothumb', body.to_json.to_s
        last_response.should be_ok
        first_body = last_response.body
        first_body.should be_a_kind_of(String)
        body = { "events" => [ { "message" => { "text" => 'http://www.pixiv.net/member_illust.php?illust_id=188556&mode=medium' } } ] }
        post '/nicothumb', body.to_json.to_s
        last_response.should be_ok
        second_body = last_response.body
        second_body.should be_a_kind_of(String)
        first_body.should == second_body
      end
    end
  end

  context 'Gyazo direct link' do
    it do
      body = { "events" => [ { "message" => { "text" => 'http://gyazo.com/cdb44db0ac247b3c01137d93ce297392' } } ] }
      post '/nicothumb', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == 'http://i.gyazo.com/cdb44db0ac247b3c01137d93ce297392.jpg'
    end
  end
end

