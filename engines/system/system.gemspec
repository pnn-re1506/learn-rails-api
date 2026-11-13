Gem::Specification.new do |spec|
  spec.name    = "system"
  spec.version = "0.1.0"
  spec.authors = [ "learn-rails-api" ]
  spec.summary = "System module: users, login, JWT"

  spec.files = Dir["{app,config,db,lib}/**/*"]

  spec.add_dependency "rails", "~> 8.1"
  spec.add_dependency "bcrypt", "~> 3.1" # has_secure_password
  spec.add_dependency "jwt", "~> 2.9"
end
