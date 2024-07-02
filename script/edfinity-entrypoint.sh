#!/bin/bash

check_and_setup_database() {
  if test -f tmp/already_setup; then
    echo "Database already set up."
  else
    echo "Database is not set up. Setting up now..."
    yarn gulp rev
    bundle exec rails db:initial_setup
    bundle exec rails canvas:compile_assets
    touch tmp/already_setup
  fi
}

check_and_setup_database

exec "$@"
