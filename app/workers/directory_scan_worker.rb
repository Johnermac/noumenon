class DirectoryScanWorker
  include Sidekiq::Worker

  def perform(domain, word, verbose = false, stealth = false)
    service = DirectoryScannerService.new(domain, nil, verbose: verbose, stealth: stealth)    
    words.each do |word|
      service.check_directory(word)
      sleep(rand(0.5..1.5)) if stealth
  end
end
