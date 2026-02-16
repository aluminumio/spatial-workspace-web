FROM ruby:3.3-slim AS base

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential libsqlite3-dev curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test

FROM base AS build

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache

COPY . .

RUN SECRET_KEY_BASE=placeholder bundle exec rails assets:precompile 2>/dev/null || true

FROM base

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

RUN useradd -m rails && chown -R rails:rails /app
USER rails

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
