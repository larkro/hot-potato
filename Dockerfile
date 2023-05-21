FROM ruby:3.1

# Update packages on ubuntu base
RUN apt-get update -q -y && apt-get upgrade -y \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

# First add Gemfile ...
COPY Gemfile* $APP_HOME/
# ... and install needed gems
RUN gem install bundler && bundle install
# So when files gets edited only that layer gets rebuilt
COPY public $APP_HOME/public
COPY app.rb config.ru puma.rb $APP_HOME/
COPY views $APP_HOME/views

EXPOSE 4567

CMD ["bundle", "exec", "puma", "-C", "puma.rb"]
