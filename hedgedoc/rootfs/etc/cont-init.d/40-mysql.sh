#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: Hedgedoc
# This validates and sets up the database
# ==============================================================================
readonly DATABASE=hedgedoc
declare host
declare port
declare username
declare password

bashio::log.debug 'Setting up database.'
# Use user-provided remote db
if ! bashio::config.is_empty 'remote_mysql_host'; then
    bashio::config.require 'remote_mysql_database' "'remote_mysql_host' is specified"
    bashio::config.require 'remote_mysql_username' "'remote_mysql_host' is specified"
    bashio::config.require 'remote_mysql_password' "'remote_mysql_host' is specified"
    bashio::config.require 'remote_mysql_port' "'remote_mysql_host' is specified"

    host=$(bashio::config 'remote_mysql_host')
    port=$(bashio::config 'remote_mysql_port')
    bashio::log.info "Using remote database at ${host}:${port}"

    # Wait until db is available.
    connected=false
    for _ in {1..30}; do
        if nc -w1 "${host}" "${port}" > /dev/null 2>&1; then
            connected=true
            break
        fi
        sleep 1
    done

    if [ $connected = false ]; then
        bashio::log.fatal
        bashio::log.fatal "Cannot connect to remote database at ${host}:${port}!"
        bashio::log.fatal "Exiting after retrying for 30 seconds."
        bashio::log.fatal
        bashio::log.fatal "Please ensure the config is set correctly and"
        bashio::log.fatal "the database is available at the specified host and port."
        bashio::log.fatal
        bashio::exit.nok
    fi

# Use mysql service provided by supervisor
else
    if ! bashio::services.available 'mysql'; then
        bashio::log.fatal
        bashio::log.fatal 'MariaDB addon not available and no alternate database supplied'
        bashio::log.fatal 'Ensure MariaDB addon is available or provide an alternate database'
        bashio::log.fatal
        bashio::exit.nok
    fi

    host=$(bashio::services 'mysql' 'host')
    port=$(bashio::services 'mysql' 'port')
    username=$(bashio::services 'mysql' 'username')
    password=$(bashio::services 'mysql' 'password')

    bashio::log.notice "Hedgedoc is using the Maria DB addon's database"
    bashio::log.notice "Please ensure that addon is included in your backups"
    bashio::log.notice "Uninstalling the Maria DB addon will also remove Hedgedoc's data"

    if bashio::config.true 'reset_database'; then
        bashio::log.warning 'Resetting database...'
        echo "DROP DATABASE IF EXISTS \`${DATABASE}\`;" \
            | mysql -h "${host}" -P "${port}" -u "${username}" -p"${password}"

        # Remove `reset_database` option
        bashio::addon.option 'reset_database'
    fi

    # Create database if it doesn't exist
    echo "CREATE DATABASE IF NOT EXISTS \`${DATABASE}\`;" \
        | mysql -h "${host}" -P "${port}" -u "${username}" -p"${password}"
fi
