FROM ruby:3.1

# Update packages on ubuntu base
RUN apt-get update -q -y && apt-get upgrade -y

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

# First add Gemfile ...
ADD Gemfile* $APP_HOME/
# ... and install needed gems
RUN gem install bundler:2.3.11
RUN bundle install
# So when files gets edited only that layer gets rebuilt
ADD public $APP_HOME/public
ADD app.rb config.ru puma.rb $APP_HOME/
ADD views $APP_HOME/views

EXPOSE 4567

CMD ["bundle", "exec", "puma", "-C", "puma.rb"]
