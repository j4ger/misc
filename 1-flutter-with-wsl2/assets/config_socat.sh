SOCAT_PORT=1145

stop_socat(){
        start-stop-daemon \
                         --oknodo --quiet --stop \
                         --pidfile /tmp/socat-$SOCAT_PORT.pid \
                         --exec /usr/bin/socat
        rm -f /tmp/socat-$SOCAT_PORT.pid
}

start_socat(){
	if [ -f "/tmp/socat-$SOCAT_PORT.pid" ]; then
		stop_socat
	fi
	start-stop-daemon \
			 --oknodo --quiet --start \
			 --pidfile /tmp/socat-$SOCAT_PORT.pid \
			 --background --make-pidfile \
			 --exec /usr/bin/socat TCP-LISTEN:$SOCAT_PORT,reuseaddr,fork TCP:$windows_host:$SOCAT_PORT < /dev/null
}

start_socat
