# One image contains all three engines. Compose selects which routes each server mounts.
FROM ruby:3.4-slim

# OS libraries: compilers for native gems + client library for MySQL (mysql2)
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential pkg-config git libyaml-dev \
      default-libmysqlclient-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# The Gemfile points to engines/*/xxx.gemspec, so the engines must be copied BEFORE bundle install
COPY Gemfile Gemfile.lock* ./
COPY engines ./engines
RUN bundle install

COPY . .

EXPOSE 3000

# db:prepare creates + migrates all 3 databases (system, website, report) if needed
CMD ["bash", "-c", "rm -f tmp/pids/server.pid && ruby bin/rails db:prepare && ruby bin/rails server -b 0.0.0.0 -p 3000"]
