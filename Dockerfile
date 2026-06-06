FROM ruby:3.3-slim

RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 1000 ragent \
 && useradd --uid 1000 --gid ragent --no-log-init --no-create-home ragent

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN chmod +x bin/ragent \
 && chown -R ragent:ragent /app \
 && chown -R ragent:ragent /usr/local/bundle

USER ragent

ENTRYPOINT ["bin/ragent"]
