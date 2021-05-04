#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: Hedgedoc
# This validates config and sets up app files/folders
# ==============================================================================
readonly CONFIG_DIR=/etc/hedgedoc
readonly DATA_DIR=/data/hedgedoc
readonly HEDGEDOC_DIR=/opt/hedgedoc
readonly DHPARAMS_FILE=/data/dhparams.pem
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
        '.production*={useSSL:true, sslCertPath:$cert, sslKeyPath:$key, dhParamPath:$dhp}' \
        "${CONFIG_DIR}/config.json" > /tmp/config.json \
    && mv /tmp/config.json "${CONFIG_DIR}/config.json"
fi


# --- CSP OPTIONS ---
bashio::log.debug 'Setting up CSP options...'
for var in $(bashio::config 'csp.directives|keys'); do
    name=$(bashio::config "csp.directives[${var}].name")
    value=$(bashio::config "csp.directives[${var}].value")
    bashio::log.info "Adding CSP directive ${name} with ${value}"
    jq \
        --arg name "${name}" \
        --arg value "${value}" \
        '.production.csp.directives[$name]|=$value' \
        "${CONFIG_DIR}/config.json" > /tmp/config.json \
    && mv /tmp/config.json "${CONFIG_DIR}/config.json"
done


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
