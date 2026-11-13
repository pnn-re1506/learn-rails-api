Gem::Specification.new do |spec|
  spec.name    = "analysis"
  spec.version = "0.1.0"
  spec.authors = [ "learn-rails-api" ]
  spec.summary = "Analysis module: record events and summarize them"

  spec.files = Dir["{app,config,db,lib}/**/*"]

  spec.add_dependency "rails", "~> 8.1"
  spec.add_dependency "system"            # Uses System::Authentication for login
end
