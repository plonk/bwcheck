#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
=begin
bwcheck -- YP4G uptest 用帯域測定クライアント

データは ~/.bwcheckrc に保存します。

インストール:

使っているライブラリは Nokogiri と Thor です。

  $ gem install nokogiri thor

bwcheck に実行ビットを付けてパスの通っているところに置いてください。

  $ install -m 755 bwcheck.rb ~/bin/bwcheck

など。

使用例:

  $ bwcheck add tp http://temp.orz.hm/yp/	# TP を追加
  $ bwcheck add sp http://bayonet.ddo.jp/sp/	# SP を追加
  $ bwcheck list				# 登録した YP 一覧
  tp: http://temp.orz.hm/yp/
  sp: http://bayonet.ddo.jp/sp/
  $ bwcheck show tp				# TP での測定情報
  $ bwcheck check sp				# SP で測定
  $ bwcheck check				# 未測定の YP で測定
  $ bwcheck check --force			# 全ての YP で再測定

=end

require 'nokogiri'
require 'open-uri'
require 'thor'
require 'yaml'

class XmlStruct
  def initialize(xml)
    @xml = xml
    # puts "I am #{self}. Nodes: #{self.class.nodes}. Attrs: #{self.class.attrs}"
    @node_classes = create_node_classes self.class.nodes
    create_nodes self.class.nodes
    create_attrs self.class.attrs
  end

  def create_node_classes(nodes)
    result = {}
    nodes.each_key do |name|
      node = Class.new(XmlStruct)
      node.class_eval(&self.class.nodes[name])
      result[name] = node
    end
    result
  end

  def create_nodes(nodes)
    nodes.each_key do |name|
      elem = @xml.children.find { |c| c.name == name.to_s }
      unless elem
        fail "#{name} element not found"
      end

      klass = @node_classes[name]
      node = klass.new(@xml.css(name.to_s).first)
      self.define_singleton_method name do
        node
      end
    end
  end

  def create_attrs attrs
    @xml.attributes.each do |name, attr|
      value = attr.value
      attr_name, elem_name, type = attrs.find { |a| a[1] == name } || [name.to_sym, name, :string
]
      case type
      when :string
        self.define_singleton_method attr_name do
          value
        end
      when :boolean
        self.define_singleton_method attr_name do
          value.to_i == 0 ? false : true
        end
      when :integral
        self.define_singleton_method attr_name do
          value.to_i
        end
      else
        fail 'unknown type'
      end
    end
  end

  class << self
    attr_reader :nodes, :attrs

    def inherited(derived)
      derived.class_init
    end

    def class_init
      @nodes = {}
      @attrs = []
    end

    # class macros
    def node(name, &block)
      @nodes[name] = block || proc {}
    end

    def attr_bool(*names)
      names.each do |sym|
        @attrs << [sym, sym.to_s.sub(/\?$/, ''), :boolean]
      end
    end

    def attr_integral(*names)
      names.each do |sym|
        @attrs << [sym, sym.to_s, :integral]
      end
    end
  end
end

class UptestStatus < XmlStruct
  node :yp

  node :host do
    attr_bool :port_open?, :over?
    attr_integral :speed
  end

  node :uptest do
    attr_bool :checkable?
    attr_integral :remain
  end

  node :uptest_srv do
    attr_integral :port, :post_size, :limit, :interval
    attr_bool :enabled?
  end
end

module Subroutines
  def random_data(data_size)
    'a' * data_size
  end

  def fmt(status)
    yp, host, uptest, srv = status.yp, status.host, status.uptest, status.uptest_srv

    <<"EOD"
イエローページ
  名前:              #{yp.name}

ホスト情報
  IPアドレス:        #{host.ip}
  速度(Kbps):        #{host.speed}
  ポート開放:        #{host.port_open?}
  3M OVER:           #{host.over?}

帯域チェック
  チェック可能:      #{uptest.checkable?}
  待ち時間残り(秒):  #{uptest.remain}

サーバー情報
  ドメイン名:        #{srv.addr}
  ポート:            #{srv.port}
  パス:              #{srv.object}
  データサイズ(KiB): #{srv.post_size}
  最大帯域(Kbps):    #{srv.limit}
  待ち時間要求(秒):  #{srv.interval}
  稼働中:            #{srv.enabled?}


EOD
  end

  def up_address(srv)
    URI.parse("http://#{srv.addr}:#{srv.port}#{srv.object}")
  end

  def show_message(srv)
    print "uploading #{srv.post_size} KiB to #{up_address(srv)} ... "
    STDOUT.flush
  end

  def run(status)
    srv = status.uptest_srv
    show_message(srv)
    Net::HTTP.post_form(up_address(srv), {'file'=>random_data(srv.post_size * 1000) })
  end

  def do_check(st)
    if st.uptest.remain > 0
      puts "#{st.yp.name} ではあと #{st.uptest.remain} 秒間は測定できません。"
      return false
    end
    run st
    puts 'ok'
    true
  rescue Errno::EPIPE
    puts 'error (connection broken)'
    false
  end

  def yp_not_registered(name)
    puts "#{name} は登録されていません。\nbwcheck add URL で登録できます。"
  end
end

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
  end

  def trim(url)
    url.sub(/yp4g\.xml$/, '').sub(/\/{0,}$/, '/')
  end

  class_init
end

class BWCheck < Thor
  include Subroutines

  class_option :verbose, type: :boolean

  desc 'show [YP]', '帯域情報表示'
  def show(name = 'all')
    if name == 'all'
      YellowPage.all.each_value do |yp|
        puts fmt yp.uptest_status
      end
    else
      yp = YellowPage.find(name)
      if yp
        puts fmt yp.uptest_status
      else
        yp_not_registered(name)
      end
    end
  end

  desc 'add NAME URL', 'イエローページを追加'
  def add(name, url)
    begin
      YellowPage.add name, url
    rescue StandardError => e
      puts "error (#{e.message})"
    end
    YellowPage.save
  end

  desc 'remove YP', 'イエローページを削除'
  def remove(name)
    YellowPage.remove name
    YellowPage.save
  end

  desc 'list', 'イエローページ一覧'
  def list
    YellowPage.all.each_pair do |mnemonic, yp|
      puts "#{mnemonic}: #{yp.url}"
    end
  end

  desc 'check [YP]', '帯域測定を行う'
  method_options %w( force -f ) => :boolean
  def check(target = 'all')
    if target == 'all'
      yps = YellowPage.all.each_pair
    else
      unless YellowPage.find(target)
        yp_not_registered(target)
        return
      end

      yps = [[target, YellowPage.find(target)]]
    end

    yps.each do |mnemonic, yp|
      st = yp.uptest_status
      if options[:force] || st.host.speed == 0
        success = do_check(st)
        if success
          yp.reload
          old_speed = st.host.speed
          new_speed = yp.uptest_status.host.speed
          puts "#{old_speed}Kbps → #{new_speed}Kbps"
        end
      else
        puts "#{yp.name} は測定済み(#{yp.uptest_status.host.speed}Kbps)です。bwcheck check #{mnemonic} --force で再測定できます。"
      end
    end
  end
end

BWCheck.start(ARGV)
