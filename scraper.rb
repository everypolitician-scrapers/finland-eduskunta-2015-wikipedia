#!/bin/env ruby
# encoding: utf-8

require 'colorize'
require 'nokogiri'
require 'open-uri'
require 'scraperwiki'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_term(url)
  noko = noko_for(url)
  table = noko.xpath(".//table[.//th[contains(.,'Puolue')]]")
  raise "Can't find unique table of Members" unless table.count == 1

  table.xpath('.//tr[td]').each do |tr|
    tds = tr.css('td')
    data = { 
      name: tds[0].css('a').first.text.tidy,
      party_id: tds[1].text.tidy.downcase,
      constituency: tds[2].text,
      wikiname: tds[0].xpath('.//a[not(@class="new")]/@title').text,
      term: 37,
    }
    data[:party_id] = 'r' if %w(rkp muu).include? data[:party_id] 
    data[:party_id] = 'sd' if data[:party_id] == 'sdp'
    ScraperWiki.save_sqlite([:name, :party_id, :term], data)
  end
end

scrape_term 'https://fi.wikipedia.org/wiki/Luettelo_vaalikauden_2015%E2%80%932019_kansanedustajista'
