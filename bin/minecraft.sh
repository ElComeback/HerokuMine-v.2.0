#!/bin/bash

# opens ngrok and see if it fails, when it does try again after 10 seconds
start_tunnel(){
	while true
	do
		echo -n "Iniciando Ngrok... "
		bin/ngrok tcp -authtoken $NGROK_API_TOKEN -log stdout --log-level debug ${mc_port} &> ngrok.log
		echo -n "Fallido, reintentando en 10 segundos... "
		sleep 10
	done
}

graceful_shutdown(){
	echo "Terminando $1 and $2"
	kill $1 $2 
	wait $1
	node last_sync.js
	exit 0
}

echo 'Esperando 30 segundos para terminar la instancia'
sleep 30
echo 'Iniciando Despliegue'

mc_port=25565


if [ -z "$NGROK_API_TOKEN" ]; then
  echo "Necesitas definir el valor NGROK_API_TOKEN para crear el tunel TCP!"
  exit 2
fi

if [ -z "$DROPBOX_API_TOKEN" ]; then
  echo "Necesitar definir el valor DROPBOX_API_TOKEN para sincronizar a Dropbox!"
  exit 3
fi

# Inicia tunel Ngrok
start_tunnel &
ngrok_pid=$!

# Descarga el mundo
node init.js

# Crea la configuración del server
if [ ! -f server.properties ]; then
  echo "server-port=${mc_port}" >> server.properties
fi
touch whitelist.json
touch banned-players.json
touch banned-ips.json
touch ops.json

heap=${HEAP:-"1G"}

echo "Iniciando: minecraft ${mc_port}"
java -Xmx${heap} -Xms${heap} -Xss512k -XX:+UseConcMarkSweepGC -jar server.jar nogui &
java_pid=$!

# trap "kill $ngrok_pid $java_pid" SIGTERM
trap "graceful_shutdown $java_pid $ngrok_pid" SIGTERM

# Inicia Sincronizacion
node sync_world.js &

# Inicia escucha en puerto: $PORT
node index.js &

# Curl el server cada 25 minutos para evitar su suspensión
while true
do
	curl --silent 'http://kodiplaza.herokuapp.com/' &> /dev/null
	sleep 1500
done
