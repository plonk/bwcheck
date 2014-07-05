require 'nokogiri'
require 'open-uri'
require 'yaml'

class YellowPage
  class << self
    URL_LIST = ENV['HOME'] + '/' + '.bwcheckrc'

    def class_init
      @registry = {}

      if File.exist? URL_LIST
        urls = YAML.load_file URL_LIST
        return if urls == false
        urls.each_pair do |name, url|
          @registry[name] = YellowPage.new(url)
        end
      end
    end

    def save
      File.open(URL_LIST, 'w') do |f|
        hash = {}
        @registry.each_pair do |name, yp|
          hash[name] = yp.url
        end
        f.write(YAML.dump(hash))
      end
    end

    def all
      @registry.dup
    end

    def add(name, url)
      if @registry.has_key? name
        fail 'already present'
      end

      new_yp = YellowPage.new url
      @registry[name] = new_yp
    end

    def remove(name)
      @registry.delete(name)
    end

    def find(name)
      @registry[name]
    end
  end

  attr_reader :name, :uptest_status, :url

  def initialize(url)
    @url = trim(url)
    reload
  end

  def reload
    xml = Nokogiri::XML open(@url + 'yp4g.xml')
    @uptest_status = UptestStatus.new xml.css('yp4g').first
    @name = uptest_status.yp.name
    self
  end

  def trim(url)
    url.sub(/yp4g\.xml$/, '').sub(/\/{0,}$/, '/')
  end

  class_init
end

