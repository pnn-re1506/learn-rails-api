Gem::Specification.new do |spec|
  spec.name    = "website"
  spec.version = "0.1.0"
  spec.authors = [ "learn-rails-api" ]
  spec.summary = "Website module: basic information about websites (domain, name)"

  spec.files = Dir["{app,config,db,lib}/**/*"]

  spec.add_dependency "rails", "~> 8.1"
  spec.add_dependency "system"            # Uses System::Authentication for login
end
