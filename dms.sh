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


#  5. Instrucciones para generar una RSA Key
function give_instructions() {
    write_title "5. Generación de llave RSA en su ordenador local"
    echo " *** SI NO TIENE UNA LLAVE RSA PÚBLICA EN SU ORDENADOR, GENERE UNA ***"
    echo "     Siga las instrucciones y pulse INTRO cada vez que termine una"
    echo "     tarea para recibir una nueva instrucción"
    echo " "
    echo "     EJECUTE LOS SIGUIENTES COMANDOS:"
    echo -n "     a) ssh-keygen "; read foo1
    echo -n "     b) scp .ssh/id_rsa.pub $username@$serverip:/home/$username/ "; read foo2
    say_done
}


#  6. Mover la llave pública RSA generada
function move_rsa() {
    write_title "6. Se moverá la llave pública RSA generada en el paso 5"
    mkdir /home/$username/.ssh
    mv /home/$username/id_rsa.pub /home/$username/.ssh/authorized_keys
    chmod 700 /home/$username/.ssh
    chmod 600 /home/$username/.ssh/authorized_keys
    chown -R $username:$username /home/$username/.ssh
    say_done
}


#  7. Securizar SSH
function ssh_reconfigure() {
    write_title "7. Securizar accesos SSH"
    
    if [ "$optional_arg" == "--custom" ]; then
        echo -n "Puerto SSH (Ej: 372): "; read puerto
    else
        puerto="372"
    fi

    sed s/USERNAME/$username/g templates/sshd_config > /tmp/sshd_config
    sed s/PUERTO/$puerto/g /tmp/sshd_config > /etc/ssh/sshd_config
    service ssh restart
    say_done
}


#  8. Establecer reglas para iptables
function set_iptables_rules() {
    write_title "8. Establecer reglas para iptables (firewall)"
    sed s/PUERTO/$puerto/g templates/iptables > /etc/iptables.firewall.rules
    iptables-restore < /etc/iptables.firewall.rules
    say_done
}


#  9. Crear script de automatizacion iptables
function create_iptable_script() {
    write_title "9. Crear script de automatización de reglas de iptables tras reinicio"
    cat templates/firewall > /etc/network/if-pre-up.d/firewall
    chmod +x /etc/network/if-pre-up.d/firewall
    say_done
}


# 10. Instalar fail2ban
function install_fail2ban() {
    # para eliminar una regla de fail2ban en iptables utilizar:
    # iptables -D fail2ban-ssh -s IP -j DROP
    write_title "10. Instalar Sendmail y fail2ban"
    apt install sendmail-bin sendmail -y
    apt install fail2ban -y
    say_done
}


# 11. Tunnear el archivo .bashrc
function tunning_bashrc() {
    write_title "19. Reemplazar .bashrc"
    cp templates/bashrc-root /root/.bashrc
    cp templates/bashrc-user /home/$username/.bashrc
    chown $username:$username /home/$username/.bashrc
    cp templates/bashrc-user /etc/skel/.bashrc
    say_done
}


# 12. Instalar, configurar y optimizar PHP
function install_php() {
    write_title "12. Instalar PHP 8.1 + Apache 2"
	apt-get -y install apt-transport-https lsb-release ca-certificates curl
	curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
	sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
	apt-get update
	apt install -y php8.1 libapache2-mod-php8.1 php8.1-mysql
    
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

# 13. Instalar librerías comunes
function install_common_libraries() {
	write_title "13. Instalar librerías para php"
	echo "13.1.  Instalar Access Control List.............."; apt install acl -y
	echo "13.2.  Instalar Openssl.........................."; apt install openssl -y
	echo "13.3.  Instalar Openssh-client..................."; apt install openssh-client -y
	echo "13.4.  Instalar Openssh-client..................."; apt install openssh-client -y
	echo "13.5.  Instalar Wget............................."; apt install wget -y
	echo "13.6.  Instalar Zip.............................."; apt install zip -y
	echo "13.7.  Instalar Libpng-dev......................."; apt install libpeng-dev -y
	echo "13.8.  Instalar Zlib1g-dev......................."; apt install zlib1g-dev -y
	echo "13.9.  Instalar Libzip-dev......................."; apt install libzip-dev -y
	echo "13.10. Instalar Libxml2-dev......................."; apt install libxml2-dev -y
	echo "13.11. Instalar Libicu-dev......................."; apt install libicu-dev -y
	echo "13.12. Instalar Intl ......................."; apt install php8.1-intl -y
	echo "13.13. Instalar Opcache ......................."; apt install php8.1-opcache -y
    say_done
}


# 14. Instalar composer 
function install_composer() {
	write_title "13. Instalar composer"
	curl https://getcomposer.org/composer.phar -o /usr/bin/composer && chmod +x /usr/bin/composer
	composer self-update	
    say_done
		
}


# 15. Instalar y tunear VIM
function install_vim() {
	apt install vim -y 
	git clone https://github.com/jkuweb/my-vim.git	
	chown -R appuser:appuser my-vim 
	mv /my-vim /home/appuser/
	mv /home/appuser/my-vim/.v* /home/appuser/
	chmod 664 /home/appuser/.vimrc
	cd /home/appuser
	 git clone https://github.com/VundleVim/Vundle.vim.git /home/appuser/.vim/bundle/Vundle.vim  
	chown -R appuser:appuser /home/appuser/.vim 
	rm -rf /home/appuser/my-vim 
    say_done
}

set_pause_on                    #  Configurar modo de pausa entre funciones
is_root_user                    #  0. Verificar si es usuario root o no
set_hostname                    #  1. Configurar Hostname
set_hour                        #  2. Configurar zona horaria
sysupdate
set_new_user                    #  4. Crear un nuevo usuario con privilegios
give_instructions               #  5. Instrucciones para generar una RSA Key
move_rsa                        #  6. Mover la llave pública RSA generada
ssh_reconfigure                 #  7. Asegurar SSH
set_iptables_rules              #  8. Establecer reglas para iptables
create_iptable_script           #  9. Crear script de automatizacion iptables
install_fail2ban				# 10. Instalar fail2ban
tunning_bashrc                  # 11. Tunnear el archivo .bashrc
install_php                     # 12. Instalar php
install_common_libraries        # 13. Instalar extensiones php y librerías 
install_composer 
install_vim
