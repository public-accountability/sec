#!/usr/bin/env ruby

require 'httparty'
require 'nokogiri'
require 'optparse'
require 'pry'

LISTING_URL = 'http://www.sec.gov/cgi-bin/browse-edgar'

Company = Struct.new(:cik, :name, keyword_init: true)
Filing = Struct.new(:date, :href, :form_name, :type, :text_href, keyword_init: true)
EdgarFilings = Struct.new(:company, :filings, :doc, keyword_init: true)

# String --> HTTP REQUEST --> String
def get_listing_xml(cik)
  params = { 'action' => 'getcompany',
             'output' => 'xml',
             'start' => 0,
             'count' => '100',
             'CIK' => cik }

  HTTParty.get(LISTING_URL, query: params).body
end


# Nokogiri::XML::Element ---> Company
def parse_company(element)
  Company.new(cik: element.at('CIK').text,
              name: element.at('name').text)
end

# Nokogiri::XML::NodeSet ---> [Filing]
def parse_filings(node_set)
  node_set.map do |filing|
    Filing.new(date: filing.at('dateFiled').text,
               href: filing.at('filingHREF').text,
               form_name: filing.at('formName').text,
               type: filing.at('type').text)
  end
end

# String --> EdgarFilings
def parse_listings(xml)
  doc = Nokogiri::XML(xml)
  company = parse_company(doc.at('companyFilings').at('companyInfo'))
  filings = parse_filings(doc.at('companyFilings').at('results').search('filing'))
  EdgarFilings.new(company: company,
                   filings: filings,
                   doc: doc)
end

def sec_filings(cik)
  parse_listing get_listing_xml(cik)
end

# The filings contain links to an SEC index page and not the filing document itself.
# In order to get the text of document we must parse that html document,
# and retive the link to the text file.
def get_submission_text_file_href(filing)
  Nokogiri::HTML(HTTParty.get(filing.href).body)
    .css('table.tableFile')
    .at_xpath("//*[contains(text(),'submission text file')]")
    .next_element
    .children
    .at('a')
    .attribute('href')
    .value
end

def verify_cik!(cik)
  fail "Missing CIK" if cik.nil? || cik.empty?
  fail "#{cik} is not a ten-digit number" unless /^[[:digit:]]{10}$/.match?(cik)
end

# Filing 
# def get_filing(filing)
#   HTTParty.get(filing.href).body
# end

verify_cik! ARGV[0]
