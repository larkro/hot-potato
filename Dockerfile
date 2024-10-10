# First stage: build the application
FROM ruby:latest AS build-env

# Update OS package
RUN apt-get update -q -y && apt-get upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV APP_HOME /app
WORKDIR $APP_HOME

# Install gems
COPY Gemfile* ./
RUN bundle config set without 'development test' \
    && bundle install

# Copy application code
COPY public ./public
COPY app.rb config.ru puma.rb ./
COPY views ./views

# Second stage: final production image
FROM ruby:latest

ENV APP_HOME /app
WORKDIR $APP_HOME

# Copy only the necessary from the build stage
COPY --from=build-env $APP_HOME $APP_HOME
COPY --from=build-env /usr/local/bundle/ /usr/local/bundle/

EXPOSE 4567

# Start the application
CMD ["bundle", "exec", "puma", "-C", "puma.rb"]
