#!/bin/sh
set -e

echo "bundle installation"
bundle check || bundle install

echo "database migartion"
bundle exec rails db:create
bundle exec rails db:schema:load
bundle exec rails db:migrate

if [ -f tmp/pids/server.pid ]; then
  rm tmp/pids/server.pid
fi

exec "$@"