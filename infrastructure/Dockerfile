FROM ruby:3.2

WORKDIR /app
COPY ./app /app

RUN apt-get update -qq && apt-get install -y nodejs postgresql-client
RUN gem install bundler && bundle install
RUN yarn install --check-files
RUN bundle exec rake assets:precompile

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
