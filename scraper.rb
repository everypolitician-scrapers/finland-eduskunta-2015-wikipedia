#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'nokogiri'
require 'open-uri'
require 'scraperwiki'
require 'scraped'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

class MembersPage < Scraped::HTML
  field :members do
    table.xpath('.//tr[td]').map do |tr|
      fragment tr => MemberRow
    end
  end

  private

  def table
    noko.xpath(".//table[.//th[contains(.,'Puolue')]]")
  end
end

class MemberRow < Scraped::HTML
  field :name do
    tds[0].css('a').first.text.tidy
  end

  field :party_id do
    pid = tds[1].text.tidy.downcase
    return 'r'  if name == 'Mats Löfström'
    return 'r'  if pid == 'rkp'
    return 'sd' if pid == 'sdp'
    pid
  end

  field :constituency do
    tds[2].text.gsub(' vaalipiiri', '')
  end

  field :wikiname do
    tds[0].xpath('.//a[not(@class="new")]/@title').text
  end

  field :term do
    37
  end

  private

  def tds
    noko.css('td')
  end
end

url = 'https://fi.wikipedia.org/wiki/Luettelo_vaalikauden_2015%E2%80%932019_kansanedustajista'
page = MembersPage.new(response: Scraped::Request.new(url: url).response)
data = page.members.map(&:to_h)
# puts data

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
ScraperWiki.save_sqlite(%i(name party_id term), data)
