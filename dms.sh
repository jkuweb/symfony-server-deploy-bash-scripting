#!/bin/bash

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

# 1. Configurar Hostname
function set_hostname() {
	write_title "1. Configurar Hostname"
	echo -n " ¿Desea configurar un hostname? (y/n): "; read config_host
	if [ "$config_host" == "y" ]; then
		echo " Ingrese un nombre para identificar a este servidor"
		echo -n " (por ejemplo: myserver) "; read host_name
		echo -n " ¿Cúal será el dominio principal? "; read domain_name
		echo $host_name > /etc/hostname
		hostname -F /etc/hostname
		echo "127.0.0.1    localhost.localdomain    localhost" >> /etc/hosts 
		echo "$serverip    $host_name.$domain_name  $host_name" >> /etc/hosts 
	fi
	say_done
}

# 2. Configurar zona horaria
function set_hour() {
    write_title "2. Configuración de la zona horaria"
    dpkg-reconfigure tzdata
    say_done
}


function sysupdate() {
    write_title "3. Actualización del sistema"
    apt update && apt upgrade -y
    say_done
}

#  4. Crear un nuevo usuario con privilegios
function set_new_user() {
    write_title "4. Creación de un nuevo usuario"
    echo -n " Indique un nombre para el nuevo usuario: "; read username
    adduser $username
    say_done
}


# 5. Tunnear el archivo .bashrc
function tunning_bashrc() {
    write_title "19. Reemplazar .bashrc"
    cp templates/bashrc-root /root/.bashrc
    cp templates/bashrc-user /home/$username/.bashrc
    chown $username:$username /home/$username/.bashrc
    cp templates/bashrc-user /etc/skel/.bashrc
    say_done
}


# 6. Instalar, configurar y optimizar PHP
function install_php() {
    write_title "12. Instalar PHP 8.1 + Apache 2"
    apt-get -y install apt-transport-https lsb-release ca-certificates curl
    curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
    sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
    apt-get update
    apt install -y php8.1 libapache2-mod-php8.1 php8.1-mysql apt install php8.1-xml apt install php8.1-mbstring
    
    a2enmod rewrite
    a2enmod php8.1

    echo -n " reemplazando archivo de configuración php.ini..."
    cp templates/php /etc/php/8.1/apache2/php.ini; echo " OK"
    service apache2 restart
    mkdir /srv/websites
    chown -R $username:$username /srv/websites
    write_title "Aloje sus WebApps en el directorio /srv/websites"
    echo "Si desea alojar sus aplicaciones en otro directorio, por favor, "
    echo "establezca la nueva ruta en la directiva open_base del archivo "
    echo "/etc/php/8.1/apache2/php.ini"
    say_done
}

# 7. Instalar librerías comunes
function install_common_libraries() {
	write_title "13. Instalar librerías para php"
	echo "13.1.  Instalar Access Control List.............."; apt install acl -y
	echo "13.2.  Instalar Openssl.........................."; apt install openssl -y
	echo "13.3.  Instalar Openssh-client..................."; apt install openssh-client -y
	echo "13.4.  Instalar Openssh-client..................."; apt install openssh-client -y
	echo "13.5.  Instalar Wget............................."; apt install wget -y
	echo "13.6.  Instalar Zip.............................."; apt install zip -y
	echo "13.7.  Instalar Libpng-dev......................."; apt install libpng-dev -y
	echo "13.8.  Instalar Zlib1g-dev......................."; apt install zlib1g-dev -y
	echo "13.9.  Instalar Libzip-dev......................."; apt install libzip-dev -y
	echo "13.10. Instalar Libxml2-dev......................."; apt install libxml2-dev -y
	echo "13.11. Instalar Libicu-dev......................."; apt install libicu-dev -y
	echo "13.12. Instalar Intl ......................."; apt install php8.1-intl -y
	echo "13.13. Instalar Opcache ......................."; apt install php8.1-opcache -y
    say_done
}


# 8. Instalar composer 
function install_composer() {
	write_title "13. Instalar composer"
	curl https://getcomposer.org/composer.phar -o /usr/bin/composer && chmod +x /usr/bin/composer
	composer self-update	
    say_done
}


# 9. Instalar y tunear VIM
function install_vim() {
	apt install vim -y 
	git clone https://github.com/jkuweb/my-vim.git	
	chown -R $username:$username my-vim/
	rm -rf /home/$username/.vim
	mv -f my-vim/.vim* /home/$username/
	git clone https://github.com/VundleVim/Vundle.vim.git /home/$username/.vim/bundle/Vundle.vim  
	
	rm -rf /root/my-vim 
    say_done
}

# Install Symfony binary
function install_symfony_binary() {
	wget https://get.symfony.com/cli/installer -O - | bash
	mv /root/.symfony*/bin/symfony /usr/local/bin/symfony
    say_done
}

#  Reiniciar servidor
function final_step() {
    write_title "27. Finalizar deploy"
    replace USERNAME $username SERVERIP $serverip PUERTO $puerto < templates/texts/bye
    echo -n " ¿Ha podido conectarse por SHH como $username? (y/n) "
    read respuesta
    if [ "$respuesta" == "y" ]; then
        reboot
    else
        # instrucciones
        echo "El servidor NO será reiniciado. Su conexión permanecerá abierta."
        cat templates/texts/bug_ubuntu_ssh
        echo "Para reiniciar el servidor escriba reboot y pulse <ENTER>"
    fi
}

set_pause_on                    #  Configurar modo de pausa entre funciones
is_root_user                    #  0. Verificar si es usuario root o no
set_hostname                    #  1. Configurar Hostname
set_hour                        #  2. Configurar zona horaria
sysupdate
set_new_user                    #  4. Crear un nuevo usuario con privilegios
tunning_bashrc                  #  5. Tunnear el archivo .bashrc
install_php                     #  6. Instalar php
install_common_libraries        #  7. Instalar extensiones php y librerías 
install_composer 
install_vim
install_symfony_binary
