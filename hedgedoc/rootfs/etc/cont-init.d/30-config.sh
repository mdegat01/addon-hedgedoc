#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: Hedgedoc
# This validates config, creates the database and sets up app files/folders
# ==============================================================================
readonly DATABASE=hedgedoc
readonly CONFIG_DIR=/etc/hedgedoc
readonly DATA_DIR=/data/hedgedoc
readonly HEDGEDOC_DIR=/opt/hedgedoc
readonly DHPARAMS_FILE=/data/dhparams.pem
declare host
declare port
declare username
declare password
declare http_port
declare domain

# --- CONFIG SUGGESTIONS/VALIDATIONS ---
bashio::log.debug 'Validate access config and look for suggestions.'
bashio::config.suggest 'access.session_secret' 'All sessions will be invalidated each time the add-on restarts.'

bashio::config.suggest 'access.domain' 'A number of HedgeDoc features do not work without it.'
if bashio::config.is_empty 'access.domain'; then
    if bashio::config.exists 'access.use_ssl'; then
        bashio::log.warning "Invalid option: 'access.use_ssl' set without an 'access.domain'. Removing..."
        bashio::addon.option 'access.use_ssl'
    fi
    if bashio::config.exists 'access.add_port'; then
        bashio::log.warning "Invalid option: 'access.add_port' set without an 'access.domain'. Removing..."
        bashio::addon.option 'access.add_port'
    fi
else
    http_port=$(bashio::addon.port '3000/tcp')
    if bashio::var.has_value "${http_port}" && [[ "${http_port}" -ne 3000 ]] && bashio::config.true 'access.add_port'; then
        domain=$(bashio::config 'access.domain')
        bashio::log.warning "When 'access.add_port' is true HedgeDoc expects to be accessed at '${domain}:3000'."
        bashio::log.warning "You've mapped port 3000 to port ${http_port} on the host."
        bashio::log.warning "Accessing HedgeDoc at '${domain}:${http_port}' won't work correctly."
        bashio::log.warning "Check the add-on documentation if you need more information."
    fi
fi


# --- SET UP SSL (if enabled) ---
bashio::log.debug 'Setting up SSL if required.'
bashio::config.require.ssl
if bashio::config.true 'ssl'; then

    # dhparam option deprecated 4/21 for release 1.1.0
    # Wait until at least 5/21 to remove entirely
    if ! bashio::config.is_empty 'dhparamfile'; then
        bashio::log.warning "The 'dhparamfile' option is deprecated. Your Diffie-Hellman key"
        bashio::log.warning "will be copied into the addon's data and the option will be removed"
        bashio::log.warning "from your configuration. You may then delete the file in /ssl."

        if bashio::fs.file_exists "/ssl/$(bashio::config 'dhparamfile')"; then
            cp "/ssl/$(bashio::config 'dhparamfile')" "${DHPARAMS_FILE}"
        else
            bashio::log.warning "File specified in 'dhparamfile' does not exist!"
            bashio::log.warning "Generating a Diffie-Hellman key instead."
        fi

        bashio::addon.option 'dhparamfile'
    fi

    if ! bashio::fs.file_exists "${DHPARAMS_FILE}"; then
        bashio::log.notice
        bashio::log.notice "Generating a Diffie-Hellman key to use for SSL."
        bashio::log.notice "This will take some time but it will only happen once."
        bashio::log.notice

        openssl dhparam -dsaparam -out "${DHPARAMS_FILE}" 4096 2> /dev/null
    fi

    # permissions
    chown abc:abc "${DHPARAMS_FILE}"

    bashio::log.info 'Setting up SSL...'
    jq \
        --arg cert "/ssl/$(bashio::config 'certfile')" \
        --arg key "/ssl/$(bashio::config 'keyfile')" \
        --arg dhp "${DHPARAMS_FILE}" \
        '. * {production: (.production * {useSSL:true, sslCertPath:$cert, sslKeyPath:$key, dhParamPath:$dhp})}' \
        "${CONFIG_DIR}/config.json" > /tmp/config.json \
    && mv /tmp/config.json "${CONFIG_DIR}/config.json"
fi


# --- SYMLINKS IN HEDGEDOC DIRECTORY ---
bashio::log.debug 'Moving files to data volume and symlinking.'
# Symlink to our config file from hedgedoc dir
rm -f "${HEDGEDOC_DIR}/config.json" || :
ln -s "${CONFIG_DIR}/config.json" "${HEDGEDOC_DIR}/config.json"

# Public folders in data volume and symlink
symlinks=( \
"${HEDGEDOC_DIR}/public/docs" \
"${HEDGEDOC_DIR}/public/uploads" \
"${HEDGEDOC_DIR}/public/views" \
"${HEDGEDOC_DIR}/public/default.md"
)
for i in "${symlinks[@]}"; do
    # if config file is present just remove container one and symlink
    if [[ -e "$i" && ! -L "$i" && -e "${DATA_DIR}/$(basename "$i")" ]]; then
        rm -Rf "$i" && \
        ln -s "${DATA_DIR}/$(basename "$i")" "$i"
    fi
    # if config file is not present move it before symlinking
    if [[ -e "$i" && ! -L "$i" ]]; then
        mv "$i" "${DATA_DIR}/$(basename "$i")" && \
        ln -s "${DATA_DIR}/$(basename "$i")" "$i"
    fi
done


# --- SET UP DATABASE ---
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

# Use our DB settings files
cp "${CONFIG_DIR}/sequelizerc" "${HEDGEDOC_DIR}/.sequelizerc"
