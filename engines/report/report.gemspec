Gem::Specification.new do |spec|
  spec.name    = "report"
  spec.version = "0.1.0"
  spec.authors = [ "learn-rails-api" ]
  spec.summary = "Report module: detailed statistics per website, combined with Website data into a final report"

  spec.files = Dir["{app,config,db,lib}/**/*"]

  spec.add_dependency "rails", "~> 8.1"
  spec.add_dependency "system"            # Uses System::Authentication for login
  spec.add_dependency "website"           # Uses Website::SiteService and Website::ReportJoin
end
