ARG RUBY_VERSION=4.0.5

FROM ruby:${RUBY_VERSION}-slim AS builder

WORKDIR /app

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
  build-essential \
  git \
  libssl-dev \
  libyaml-dev \
  libpq-dev \
  tzdata \
  && ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime \
  && echo "Europe/London" > /etc/timezone \
  && rm -rf /var/lib/apt/lists/*

COPY .ruby-version Gemfile Gemfile.lock /app/
RUN bundle install --jobs=4 --no-binstubs

COPY . /app/

RUN SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bundle exec rails assets:precompile

RUN rm -rf log tmp \
  && rm -rf /usr/local/bundle/cache \
  && rm -rf .env \
  && find /usr/local/bundle/gems -name "*.c" -delete \
  && find /usr/local/bundle/gems -name "*.h" -delete

FROM ruby:${RUBY_VERSION}-slim

WORKDIR /app

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
  postgresql-client \
  tzdata \
  && ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app /app

RUN mkdir -p log tmp/pids

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
