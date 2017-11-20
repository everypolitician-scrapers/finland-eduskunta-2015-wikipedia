#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MembersPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links

  field :members do
    table.xpath('.//tr[td]').map do |tr|
      fragment tr => MemberRow
    end
  end

  private

  def table
    # TODO: changes
    noko.xpath(".//table[.//th[contains(.,'Puolue')]]").first
  end
end

class MemberRow < Scraped::HTML
  field :name do
    tds[0].css('a').first.text.tidy
  end

  field :sort_name do
    tds[0].css('span[style="display:none;"]').text
  end

  field :wikidata do
    tds[0].css('a/@wikidata').text
  end

  field :party do
    tds[2].text.tidy || ''
  end

  field :party_wikidata do
    tds[2].css('a/@wikidata').text
  end

  field :constituency do
    tds[3].text.gsub(' vaalipiiri', '')
  end

  field :constituency_wikidata do
    tds[3].css('a/@wikidata').text
  end

  field :wikiname do
    tds[0].xpath('.//a[not(@class="new")]/@title').text
  end

  field :term do
    37
  end

  field :start_date do
    return unless tds[6].text.include? 'seuraajaksi'
    Date.new(*tds[6].text[/(\d+\.\d+.\d{4})/].split('.').reverse.map(&:to_i)).to_s
  end

  field :replaces do
    return unless start_date
    tds[6].at_css('a/@title').text
  end

  private

  def tds
    noko.css('td')
  end
end

url = 'https://fi.wikipedia.org/wiki/Luettelo_vaalikauden_2015%E2%80%932019_kansanedustajista'
page = MembersPage.new(response: Scraped::Request.new(url: url).response)
data = page.members.map(&:to_h).map { |m| m.reject { |_, v| v.to_s.empty? } }

data.select { |m| m.key? :replaces }.each do |new|
  replaced = data.find { |old| old[:wikiname] == new[:replaces] } or raise "Can't find #{new[:replaces]}"
  replaced[:end_date] = new[:start_date]
end

data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']
ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[name term], data)
