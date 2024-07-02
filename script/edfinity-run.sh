#!/bin/bash

check_database() {
  if test -f tmp/already_setup; then
    echo "Database already set up."
  else
    echo "Database is not set up. Exiting"
    exit 0
  fi
}

check_database

exec "$@"
