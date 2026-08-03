ARG RUBY_VERSION=4.0.5
ARG ALPINE_VERSION=3.23

FROM ruby:${RUBY_VERSION}-alpine${ALPINE_VERSION} AS builder

WORKDIR /app

RUN apk add --update --no-cache \
  build-base \
  git \
  openssl-dev \
  yaml-dev \
  postgresql-dev \
  tzdata \
  && cp /usr/share/zoneinfo/Europe/London /etc/localtime \
  && echo "Europe/London" > /etc/timezone

RUN bundle config set without "development test"
COPY .ruby-version Gemfile Gemfile.lock /app/
RUN bundle install --jobs=4 --no-binstubs

COPY . /app/

RUN SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bundle exec rails assets:precompile

RUN rm -rf log tmp \
  && rm -rf /usr/local/bundle/cache \
  && rm -rf .env \
  && find /usr/local/bundle/gems -name "*.c" -delete \
  && find /usr/local/bundle/gems -name "*.h" -delete

FROM ruby:${RUBY_VERSION}-alpine${ALPINE_VERSION}

WORKDIR /app

RUN apk add --update --no-cache \
  postgresql-client \
  tzdata \
  && cp /usr/share/zoneinfo/Europe/London /etc/localtime

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app /app

RUN mkdir -p log tmp/pids

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
