#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: Hedgedoc
# This validates config, creates the database and sets up app files/folders
# ==============================================================================

database=hedgedoc
data_dir=/data/hedgedoc
hedgedoc_dir=/opt/hedgedoc

# create symlinks
symlinks=( \
"${hedgedoc_dir}/public/docs" \
"${hedgedoc_dir}/public/uploads" \
"${hedgedoc_dir}/public/views" \
"${hedgedoc_dir}/public/default.md"
)
for i in "${symlinks[@]}"; do
    # if config file is present just remove container one and symlink
    [[ -e "$i" && ! -L "$i" && -e "${data_dir}/$(basename "$i")" ]] && \
        rm -Rf "$i" && \
        ln -s "${data_dir}/$(basename "$i")" "$i"
    # if config file is not present move it before symlinking
    [[ -e "$i" && ! -L "$i" ]] && \
        mv "$i" "${data_dir}/$(basename "$i")" && \
        ln -s "${data_dir}/$(basename "$i")" "$i"
done
rm -f "${hedgedoc_dir}/config.json" || :
ln -s /etc/hedgedoc/config.json "${hedgedoc_dir}/config.json"

# Use user-provided remote db
if bashio::config.exists 'remote_mysql_host'; then
    bashio::config.require 'remote_mysql_database' "'remote_mysql_host' is specified"
    bashio::config.require 'remote_mysql_username' "'remote_mysql_host' is specified"
    bashio::config.require 'remote_mysql_password' "'remote_mysql_host' is specified"
    bashio::config.require 'remote_mysql_port' "'remote_mysql_host' is specified"

    host=$(bashio::config 'remote_mysql_host')
    port=$(bashio::config 'remote_mysql_port')
    bashio::log.info "Using remote database at ${host}:${port}"

    # Wait until db is available.
    for _ in $(seq 1 30); do
        if /bin/nc -w1 "${host}" "${port}" > /dev/null 2>&1; then
            break
        fi
        sleep 1
    done

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

    bashio::log.warning "Hedgedoc is using the Maria DB addon's database"
    bashio::log.warning "Please ensure that addon is included in your backups"
    bashio::log.warning "Uninstalling the Maria DB addon will also remove Hedgedoc's data"

    if bashio::config.true 'reset_database'; then
        bashio::log.warning 'Resetting database...'
        echo "DROP DATABASE IF EXISTS \`${database}\`;" \
            | mysql -h "${host}" -P "${port}" -u "${username}" -p"${password}"

        # Remove `reset_database` option
        bashio::addon.option 'reset_database'
    fi

    # Create database if it doesn't exist
    echo "CREATE DATABASE IF NOT EXISTS \`${database}\`;" \
        | mysql -h "${host}" -P "${port}" -u "${username}" -p"${password}"
fi

# Use our DB settings files
cp /etc/hedgedoc/sequelizerc "${hedgedoc_dir}/.sequelizerc"
