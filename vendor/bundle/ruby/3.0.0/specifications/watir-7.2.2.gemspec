# -*- encoding: utf-8 -*-
# stub: watir 7.2.2 ruby lib

Gem::Specification.new do |s|
  s.name = "watir".freeze
  s.version = "7.2.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Alex Rodionov".freeze, "Titus Fortner".freeze, "Justin Ko".freeze]
  s.date = "2023-01-03"
  s.description = "Watir stands for Web Application Testing In Ruby\nIt facilitates the writing of automated tests by mimicing the behavior of a user interacting with a website.\n".freeze
  s.email = ["p0deje@gmail.com".freeze, "titusfortner@gmail.com".freeze, "jkotests@gmail.com ".freeze]
  s.homepage = "https://github.com/watir/watir".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7.0".freeze)
  s.rubygems_version = "3.3.5".freeze
  s.summary = "Watir powered by Selenium".freeze

  s.installed_by_version = "3.3.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<regexp_parser>.freeze, [">= 1.2", "< 3"])
    s.add_runtime_dependency(%q<selenium-webdriver>.freeze, ["~> 4.2"])
    s.add_development_dependency(%q<activesupport>.freeze, ["~> 4.0", ">= 4.1.11"])
    s.add_development_dependency(%q<coveralls_reborn>.freeze, [">= 0"])
    s.add_development_dependency(%q<nokogiri>.freeze, [">= 1.14.0.rc1"])
    s.add_development_dependency(%q<pry>.freeze, ["~> 0.14"])
    s.add_development_dependency(%q<rake>.freeze, [">= 12.3.3"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_development_dependency(%q<rspec-retry>.freeze, [">= 0"])
    s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.42"])
    s.add_development_dependency(%q<rubocop-performance>.freeze, ["~> 1.15"])
    s.add_development_dependency(%q<rubocop-rake>.freeze, ["~> 0.6"])
    s.add_development_dependency(%q<rubocop-rspec>.freeze, ["~> 2.16"])
    s.add_development_dependency(%q<selenium_statistics>.freeze, [">= 0"])
    s.add_development_dependency(%q<selenium-webdriver>.freeze, ["~> 4.7"])
    s.add_development_dependency(%q<simplecov-console>.freeze, [">= 0"])
    s.add_development_dependency(%q<webidl>.freeze, [">= 0.2.2"])
    s.add_development_dependency(%q<yard>.freeze, ["> 0.9.11"])
    s.add_development_dependency(%q<yard-doctest>.freeze, ["~> 0.1.14"])
  else
    s.add_dependency(%q<regexp_parser>.freeze, [">= 1.2", "< 3"])
    s.add_dependency(%q<selenium-webdriver>.freeze, ["~> 4.2"])
    s.add_dependency(%q<activesupport>.freeze, ["~> 4.0", ">= 4.1.11"])
    s.add_dependency(%q<coveralls_reborn>.freeze, [">= 0"])
    s.add_dependency(%q<nokogiri>.freeze, [">= 1.14.0.rc1"])
    s.add_dependency(%q<pry>.freeze, ["~> 0.14"])
    s.add_dependency(%q<rake>.freeze, [">= 12.3.3"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_dependency(%q<rspec-retry>.freeze, [">= 0"])
    s.add_dependency(%q<rubocop>.freeze, ["~> 1.42"])
    s.add_dependency(%q<rubocop-performance>.freeze, ["~> 1.15"])
    s.add_dependency(%q<rubocop-rake>.freeze, ["~> 0.6"])
    s.add_dependency(%q<rubocop-rspec>.freeze, ["~> 2.16"])
    s.add_dependency(%q<selenium_statistics>.freeze, [">= 0"])
    s.add_dependency(%q<selenium-webdriver>.freeze, ["~> 4.7"])
    s.add_dependency(%q<simplecov-console>.freeze, [">= 0"])
    s.add_dependency(%q<webidl>.freeze, [">= 0.2.2"])
    s.add_dependency(%q<yard>.freeze, ["> 0.9.11"])
    s.add_dependency(%q<yard-doctest>.freeze, ["~> 0.1.14"])
  end
end
