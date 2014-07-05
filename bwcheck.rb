#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require_relative 'uptest_status'
require_relative 'yellow_page'

class BWCheckImp
  attr_reader :options

  def initialize(options)
    @options = options
  end

  def show(name)
    if name == 'all'
      show_all
    else
      if yp = YellowPage.find(name)
        puts fmt yp.uptest_status
      else
        yp_not_registered(name)
      end
    end
  end

  def show_all
    YellowPage.all.each_pair do |mnem, yp|
      st = yp.uptest_status
      speed = st.host.speed == 0 ? '未測定' : "#{st.host.speed.to_s}Kbps"
      puts "#{mnem}: #{speed}"
    end
  end

  def add name, url
    fail 'all is a keyword' if name == 'all'
    YellowPage.add name, url
    YellowPage.save
  rescue StandardError => e
    puts "error (#{e.message})"
  end

  def remove name
    YellowPage.remove name
    YellowPage.save
  rescue StandardError => e
    puts "error (#{e.message})"
  end

  def list
    YellowPage.all.each_pair do |mnemonic, yp|
      puts "#{mnemonic}: #{yp.url}"
    end
  end

  def check(target)
    if target == 'all'
      YellowPage.all.each_key do |ypname|
        check_one(ypname)
      end
    else
      check_one(target)
    end
  end

  def check_one(target)
    unless yp = YellowPage.find(target)
      yp_not_registered(target)
      return
    end

    before = yp.uptest_status
    if options[:force] || before.host.speed == 0
      if success = do_check(before)
        after = yp.reload.uptest_status
        puts "#{before.host.speed}Kbps → #{after.host.speed}Kbps"
      end
    else
      puts "#{yp.name} は測定済み(#{before.host.speed}Kbps)です。(use --force)"
    end
  end

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

  def show_uploading_message(srv)
    print "uploading #{srv.post_size} KiB to #{up_address(srv)} ... "
    STDOUT.flush
  end

  def run(status)
    srv = status.uptest_srv

    show_uploading_message(srv)
    Net::HTTP.post_form(up_address(srv), { 'file'=>random_data(srv.post_size * 1000) })
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
