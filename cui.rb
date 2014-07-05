# -*- coding: utf-8 -*-
require 'thor'
require_relative 'bwcheck'

class BWCheckCUI < Thor
  class_option :verbose, type: :boolean

  desc 'show [YP]', '帯域情報表示'
  def show(name = 'all')
    BWCheckImp.new(options).show(name)
  end

  desc 'add NAME URL', 'イエローページを追加'
  def add(name, url)
    BWCheckImp.new(options).add(name, url)
  end

  desc 'remove YP', 'イエローページを削除'
  def remove(name)
    BWCheckImp.new(options).remove(name)
  end

  desc 'list', 'イエローページ一覧'
  def list
    BWCheckImp.new(options).list
  end

  desc 'check [YP]', '帯域測定を行う'
  method_options %w( force -f ) => :boolean
  def check(target = 'all')
    BWCheckImp.new(options).check(target)
  end
end

BWCheckCUI.start(ARGV)
