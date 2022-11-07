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


# 3. Actualizar el sistema
function sysupdate() {
    write_title "3. Actualización del sistema"
    apt update && apt upgrade -y
    say_done
}


# 4. Crear un nuevo usuario con privilegios
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
	echo 'alias ..="cd .."' >> /home/$username/.bashrc
	echo 'alias ls -la="lsa"' >> /home/$username/.bashrc
    say_done
}


# 6. Instalar, configurar y optimizar PHP
function install_php() {
    write_title "12. Instalar PHP 8.1 + Apache 2"
    apt-get -y install apt-transport-https lsb-release ca-certificates curl
    curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
    sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
    apt-get update
       apt install -y \
		php8.1 \
		libapache2-mod-php8.1 \
		php8.1-mysql \
		php8.1-xml \
		php8.1-mbstring \
		php8.1-zip \
		php8.1-curl \
		php8.1-gd \
		apache2  \
		libapache2-mod-wsgi-py3 \
		python-dev-is-python3

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
	echo "13.6.  Instalar Unzip............................"; apt install unzip -y
	echo "13.7.  Instalar Libpng-dev......................."; apt install libpng-dev -y
	echo "13.8.  Instalar Zlib1g-dev......................."; apt install zlib1g-dev -y
	echo "13.9.  Instalar Libzip-dev......................."; apt install libzip-dev -y
	echo "13.10. Instalar Libxml2-dev......................"; apt install libxml2-dev -y
	echo "13.11. Instalar Libicu-dev......................."; apt install libicu-dev -y
	echo "13.12. Instalar Intl ............................"; apt install php8.1-intl -y
	echo "13.13. Instalar Opcache ........................."; apt install php8.1-opcache -y
	echo "13.14. Instalar Manpages-dev ...................."; apt install manpages-dev -y
	echo "13.15. Instalar Libc-devtools ..................."; apt install libc-devtools -y
    say_done
}


# 10. Instalar ModEvasive
function install_modevasive() {
    write_title "16. Instalar ModEvasive"
    echo -n " Indique e-mail para recibir alertas: "; read inbox
    
    if [ "$inbox" == "" ]; then
        inbox="root@localhost"
    fi
    
    apt install libapache2-mod-evasive -y
    mkdir /var/log/mod_evasive
    chown www-data:www-data /var/log/mod_evasive/
    modevasive="/etc/apache2/mods-available/mod-evasive.conf"
    sed s/MAILTO/$inbox/g templates/mod-evasive > $modevasive
    a2enmod evasive
    service apache2 restart
    say_done
}


# 8. Instalar OWASP para ModSecuity
function install_owasp_core_rule_set() {
    write_title "14. Instalar OWASP ModSecurity Core Rule Set"
    apt install libmodsecurity3 -y
    
    write_title "14.2 Clonar repositorio"

    wget https://github.com/coreruleset/coreruleset/archive/refs/tags/v3.3.4.tar.gz /etc/apache2/modsecurity.d
    tar -xzvf v3.3.4.tar.gz
    mv coreruleset-3.3.4/ owasp-modsecurity-crs/
    mv  owasp-modsecurity-crs/ /etc/apache2/modsecurity.d/
    
    write_title "14.3 Mover archivo de configuración"
    mv /etc/apache2/modsecurity.d/owasp-modsecurity-crs/crs-setup.conf.example \
     /etc/apache2/modsecurity.d/owasp-modsecurity-crs/crs-setup.conf
    
    write_title "14.4 Renombrar reglas de pre y post ejecución" 

    mv /etc/apache2/modsecurity.d/owasp-modsecurity-crs/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example \
     /etc/apache2/modsecurity.d/owasp-modsecurity-crs/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf

    mv /etc/apache2/modsecurity.d/owasp-modsecurity-crs/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example \
     /etc/apache2/modsecurity.d/owasp-modsecurity-crs/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf
    write_title "14.5 modsecurity.conf-recommended" 
    touch /etc/apache2/modsecurity.d/owasp-modsecurity-crs/modsecurity.conf
    echo templates/modsecurity >> /etc/apache2/modsecurity.d/owasp-modsecurity-crs/modsecurity.conf
    
    modsecrec="/etc/apache2/modsecurity.d/owasp-modsecurity-crs/modsecurity.conf"
    sed s/SecRuleEngine\ DetectionOnly/SecRuleEngine\ On/g $modsecrec > /tmp/salida   
    mv /tmp/salida /etc/apache2/modsecurity.d/owasp-modsecurity-crs/modsecurity.conf
    
    if [ "$optional_arg" == "--custom" ]; then
        echo -n "Firma servidor: "; read firmaserver
        echo -n "Powered: "; read poweredby
    else
        firmaserver="Oracle Solaris 11.2"
        poweredby="n/a"
    fi    
    
    modseccrs10su="/etc/apache2/modsecurity.d/owasp-modsecurity-crs/crs-setup.conf"
    echo "SecServerSignature \"$firmaserver\"" >> $modseccrs10su
    echo "Header set X-Powered-By \"$poweredby\"" >> $modseccrs10su

    a2enmod headers
    service apache2 restart
    say_done
}


# 9. Configurar y optimizar Apache
function configure_apache() {
    write_title "15. Finalizar configuración y optimización de Apache"
    cp templates/apache /etc/apache2/apache2.conf
    service apache2 restart
    say_done
}


# 10. Instalar composer 
function install_composer() {
	write_title "13. Instalar composer"
	curl https://getcomposer.org/composer.phar -o /usr/bin/composer && chmod +x /usr/bin/composer
	composer self-update	
    say_done
}


# 11. Instalar y tunear VIM
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
	echo 'alias sf="php bin/console"' >> /home/$username/.bashrc
    say_done
}

# Create virtualHost file 
function install_virtualhost() {
	sed s/DOMAIN_NAME/$domain_name/g templates/apache-symfony > /etc/apache2/sites-available/000-$domain_name.conf
	rm /etc/apache2/sites-enabled/000-default.conf
	a2ensite 000-$domain_name.conf
	systemctl restart apache2
    say_done
}


set_pause_on                    
is_root_user                    
set_hostname                    
set_hour                        
sysupdate
set_new_user                    
tunning_bashrc                  
install_php                     
install_common_libraries        
install_owasp_core_rule_set
#configure_apache
#install_modevasive
install_composer 
install_vim
install_symfony_binary
install_virtualhost
