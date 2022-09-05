#!/bin/bash

#Configuring Permissions for Symfony Applications

source helpers.sh
declare -r optional_arg="$1"

export serverip=$(__get_ip)

# 0. Verificar si es usuario root o no
function is_root_user() {
        if [ echo whoami != "root" ]; then
                echo "Permiso denegado."
                echo "Este programa solo puede ser ejecutado por el usuario root"
                exit
        else
                clear
                cat templates/texts/welcome
        fi
}

# Configurar  DomainName
function set_domain_name() {
     write_title "1. Dominio principal"
     echo -n " ¿Cúal será el dominio principal? "; read domain_name
     say_done
}


# Configuring Permissions for Symfony Applications
function configured_permissions_symfony() {
        HTTPDUSER=$(ps axo user,comm | grep -E '[a]pache|[h]ttpd|[_]www|[w]ww-data|[n]ginx' | grep -v root | head -1 | cut -d\  -f1)
        setfacl -dR -m u:"$HTTPDUSER":rwX -m u:$(whoami):rwX /srv/websites/$domain_name/var
        setfacl -R -m u:"$HTTPDUSER":rwX -m u:$(whoami):rwX /srv/websites/$domain_name/var
}


set_pause_on
is_root_user
set_domain_name
configured_permissions_symfony
