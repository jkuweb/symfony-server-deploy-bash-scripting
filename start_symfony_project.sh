#!/bin/bash

#Configuring Permissions for Symfony Applications

source helpers.sh
declare -r optional_arg="$1"

export serverip=$(__get_ip)
# 0. Verificar si es usuario root o no 
function is_root_user() { 
   if [ echo whoami == "root" ]; then 
		   echo "Permiso denegado." 
		   echo -n "Este programa no puede ser ejecutado por el usuario root" 
		   exit 
   else 
		   clear 
		   cat templates/texts/welcome 
   fi 
} 

# 1. Configurar Hostname
function set_hostname() {
     write_title "1. Dominio principal"
     echo -n " ¿Cúal será el dominio principal? "; read domain_name 
     say_done
}


# 2. Lanzar Composer 
function execute_composer() {
     write_title "2. Lanzar composer"
     (cd /srv/websites/$domain_name/ && composer install)
     say_done
}


# 3. Realizar la migraci�n a la base de datos 
function execute_doctrine_migrations() {
     write_title "3. Realizar la migracion a la base de datos"
     (cd /srv/websites/$domain_name/ && bin/console doctrine:migrations:migrate)
     
     say_done
}


# 4. Limpiar la cache 
function execute_clear_cache() {
     write_title "4. Limpiar la cache"
     (cd /srv/websites/$domain_name/ && bin/console cache:clear)
     say_done
}


# 5. Ejecutar dump-autoload 
function execute_dump_autoload() {
     write_title "5. Ejecutar `dump-autoload`"
     (cd /srv/websites/$domain_name/ && composer dump-autoload --optimize --no-dev --classmap-authoritative)
     say_done
}


# 6. Generar el fichero `.env.prod.php'"
function generated_production_envirenment_file() {
     write_title "6. General el fichero de entorno de producci�n" 
     (cd /srv/websites/$domain_name/ && composer dump-env prod)
     say_done
}


set_pause_on
is_root_user
set_hostname
execute_composer
execute_doctrine_migrations
execute_clear_cache
execute_dump_autoload
generated_production_envirenment_file
