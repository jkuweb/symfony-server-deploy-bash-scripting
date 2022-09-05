#!/bin/bash

#Configuring Permissions for Symfony Applications

source helpers.sh
declare -r optional_arg="$1"

export serverip=$(__get_ip)


# 0. Verificar si es usuario root o no 
function is_root_user() {
     user=$(id -u)
     write_title "Verificar si no es usuario root"
     if [ $user == 0  ]; then
      echo "Permiso denegado." 
      echo -n "Este programa no puede ser ejecutado por el usuario root"
      exit
   else
      clear
      cat templates/texts/welcome
   fi
}

# 1. Configurar el dominio
function set_domain() {
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




# 5. Ejecutar dump-autoload 
function execute_dump_autoload() {
     write_title "5. Ejecutar dump-autoload"
     (cd /srv/websites/$domain_name/ && composer dump-autoload --optimize --no-dev --classmap-authoritative)
     say_done
}



# 6. Generar el fichero `.env.prod.php'"
function generated_production_envirenment_file() {
     write_title "6. General el fichero de entorno de producci�n"

     file_path=/srv/websites/$domain_name/.env
     sed -i -e 's/APP_ENV=env/APP_ENV=prod/g' $file_path
     number=$(grep -n DATABASE_URL  $file_path | grep -Eo '^[^:]+')
     sed -i "${number}d" $file_path

     sed -i -e "s/SITE_BASE_URL=https:\/\/localhost:8000/SITE_BASE_URL=${domain_name}/g" $file_path

     echo -n " Indica el usuario de la DDBB: "; read db_user_name
     echo -n "Introduce el password para la DDBB: "; read db_psswd
     echo -n "Indica el nombre de la DDBB: "; read db_name
     echo -n "Indica el la IP del servidor donde se aloja la DDBB: "; read db_host
     DATABASE_URL="DATABASE_URL='mysql://${db_user_name}:${db_psswd}@${db_host}:3306/${db_name}?serverVersion=8.0&charset=utf8mb4'"
     echo $DATABASE_URL >> $file_path
     (cd /srv/websites/$domain_name/ && composer dump-env prod)

     say_done
}


# 3. Realizar la migraci�n a la base de datos 
function execute_doctrine_migrations() {
     write_title "3. Realizar la migracion a la base de datos"
     (cd /srv/websites/$domain_name/ && php bin/console doctrine:migrations:migrate --no-interaction)

     say_done
}

# 4. Limpiar la cache 
function execute_clear_cache() {
     write_title "4. Limpiar la cache"
     (cd /srv/websites/$domain_name/ && php bin/console cache:clear)
     say_done
}

set_pause_on
is_root_user
set_domain
execute_composer
execute_dump_autoload
generated_production_envirenment_file
execute_doctrine_migrations
execute_clear_cache

