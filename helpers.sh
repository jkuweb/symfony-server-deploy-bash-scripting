#!/bin/bash

# Configuración de colores
resaltado="\033[1m\033[1m"
verde="\033[33m"
normal="\033[1m\033[0m"


# Escribir el título en colores
function write_title() {
    echo " "
    echo -e "$resaltado $1 $normal"
    say_continue
}


# Mostrar mensaje "Done."
function say_done() {
    echo " "
    echo -e "$verde Done. $normal"
    say_continue
}


# Preguntar para continuar
function say_continue() {
    if [ "$pause" == "on" ]; then
        echo -n " Para SALIR, pulse la tecla x; sino, pulse ENTER para continuar..."
        read acc
        if [ "$acc" == "x" ]; then
            exit
        fi
    fi
    echo " "
}


# Pausar antes de continuar
function set_pause_on() {
    if [ "$optional_arg" == "--custom" ]; then
        echo " "
        echo -en "$resaltado Pause Mode (on/off): $normal"; read pause
    else
        pause="on"
    fi
}


# Instalar CLI alternativo para PHP
function get_phpcli() {
    wget https://launchpad.net/phpclialternative/trunk/0.3.5/+download/phpcli_0.3.5.deb
    dpkg -i phpcli_0.3.5.deb
}


# Obtener la IP pública
function __get_ip() {
	serverip=`hostname -I | awk '{print $1 " "}'`
	echo $serverip
}
