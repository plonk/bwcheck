#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'nokogiri'
require 'open-uri'
require 'thor'
require 'yaml'
require_relative 'uptest_status'
require_relative 'yellow_page'

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
