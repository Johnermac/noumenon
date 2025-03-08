require "httparty"

class ScanWorker
  include HTTParty
  include Sidekiq::Worker

  def perform(site)
    wordlist_path = Rails.root.join("tmp", "wordlist.txt")

    unless File.exist?(wordlist_path)
      puts "\n\t❌ Wordlist file not found at #{wordlist_path}"
      return
    end

    directories = File.readlines(wordlist_path).map(&:strip).reject(&:empty?)

    found_directories = []
    not_found_directories = []

    directories.each do |dir|
      url = "#{site}/#{dir}"
      response = HTTParty.get(url)

      if response.code == 200
        found_directories << dir
      else
        not_found_directories << dir
      end
    end

    puts "\n  Scan Results for #{site}:"
    puts "    \t✅ Found Directories: #{found_directories.join(', ')}" if found_directories.any?
    puts "    \t❌ Not Found Directories: #{not_found_directories.join(', ')}\n" if not_found_directories.any?
  end
end
