FROM ruby:3.3.5 AS build-env

# Update OS package
RUN apt-get update -q -y && apt-get upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

# First add Gemfile ...
COPY Gemfile* $APP_HOME/
# ... and install needed gems
RUN gem install bundler \
    && bundle config --global frozen 1 \
    && bundle install

# So when files gets edited only that layer gets rebuilt
COPY public $APP_HOME/public
COPY app.rb config.ru puma.rb $APP_HOME/
COPY views $APP_HOME/views

### Second stage
FROM ruby:3.3.5-slim

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

RUN apt-get update -q -y && apt-get upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build-env $APP_HOME $APP_HOME
COPY --from=build-env /usr/local/bundle/ /usr/local/bundle/

EXPOSE 4567

CMD ["bundle", "exec", "puma", "-C", "puma.rb"]
