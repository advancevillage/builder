#!/usr/bin/env bash

build_root="$root/build"

function deb_config_dir () {
    project=${1:-""}
    [ -d $build_root ]                  || mkdir -p $build_root
    [ -d $build_root/etc ]              || mkdir -p $build_root/etc
    [ -d $build_root/etc/default ]      || mkdir -p $build_root/etc/default
    [ -d $build_root/etc/init.d ]       || mkdir -p $build_root/etc/init.d
    [ -d $build_root/etc/logrotate.d ]  || mkdir -p $build_root/etc/logrotate.d
    [ -d $build_root/etc/$project ]     || mkdir -p $build_root/etc/$project

    [ -d $build_root/usr ]              || mkdir -p $build_root/usr
    [ -d $build_root/usr/sbin ]         || mkdir -p $build_root/usr/sbin

    [ -d $build_root/var ]              || mkdir -p $build_root/var
    [ -d $build_root/var/run ]          || mkdir -p $build_root/var/run
    [ -d $build_root/var/log ]          || mkdir -p $build_root/var/log

    gen_etc_default     $project
    gen_etc_initd       $project
    gen_etc_config      $project
    gen_etc_logrotate   $project

    gen_var             $project
}

function gen_etc_default() {
    project=${1:-""}
    dir="$build_root/etc/default/$project"
    cat << EOF > $dir
# Defaults for $project initscript
# sourced by /etc/init.d/$project

# Additional options that are passed to $project
DAEMON_ARGS=""
EOF
}

function gen_etc_initd() {
    project=${1:-""}
    dir="$build_root/etc/init.d/$project"
    cat << EOF > $dir
#!/bin/bash
### BEGIN INIT INFO
# Provides:          $project
# Required-Start:    $network $remote_fs $local_fs
# Required-Stop:     $network $remote_fs $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Stop/start $project
### END INIT INFO

# Author: Richard Sun <cugriver@163.com>

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

[ -r /etc/default/$project ] && . /etc/default/$project

NAME=$project
DESC=$project
CONFFILE=/etc/$project/$project.json
DAEMON=/usr/sbin/\$NAME
DAEMON_ARGS="-c \$CONFFILE \$DAEMON_ARGS"

PIDFILE=\$(egrep "pid" \$CONFFILE  | awk -F\" '{print \$4}')
RUNDIR=\$(dirname \$PIDFILE)

test -x \$DAEMON || exit 0

. /lib/lsb/init-functions

set -e

if [ "\$(id -u)" != "0" ]; then
	log_failure_msg "Must be run as root."
	exit 1
fi

case "\$1" in
  start)
    echo -n "Starting \$DESC: "
    if [ \$(egrep "\$NAME" /etc/group | wc -l) -eq 0 ]; then
        groupadd \$NAME
    fi
    if [ \$(egrep "\$NAME" /etc/passwd | wc -l) -eq 0 ]; then
        useradd -c "\$NAME" -g \$NAME \$NAME
    fi
	mkdir -p \$RUNDIR
	touch \$PIDFILE
	chown \$NAME:\$NAME \$RUNDIR \$PIDFILE
	chmod 755 \$RUNDIR

	if [ -n "\$ULIMIT" ]; then
		ulimit -n \$ULIMIT || true
	fi

	if start-stop-daemon --start --background --quiet --oknodo --umask 007 --pidfile \$PIDFILE --chuid \$NAME:\$NAME --exec \$DAEMON -- \$DAEMON_ARGS
	then
		echo "\$NAME."
	else
		echo "failed"
	fi
	;;
  stop)
	echo -n "Stopping \$DESC: "

	if start-stop-daemon --stop --signal "TERM" --retry 5 --quiet --oknodo --pidfile \$PIDFILE --exec \$DAEMON
	then
		echo "\$NAME."
	else
		echo "failed"
	fi
	rm -f \$PIDFILE
	sleep 1
	;;

  restart|force-reload)
	\${0} stop
	\${0} start
	;;

  status)
	status_of_proc -p \${PIDFILE} \${DAEMON} \${NAME}
	;;

  *)
	echo "Usage: /etc/init.d/\$NAME {start|stop|restart|force-reload|status}" >&2
	exit 1
	;;
esac

exit 0
EOF
}

function gen_etc_config() {
    project=${1:-""}
    dir="$build_root/etc/$project/$project.json"
    cat << EOF > $dir
{
    "pid": "/var/run/$project/$project.pid",
    "database": {},
    "log":{}
}
EOF
}

function gen_etc_logrotate() {
    project=${1:-""}
    dir="$build_root/etc/logrotate.d/$project"
    cat << EOF > $dir
/var/log/$project/*.log {
        daily
        missingok
        rotate 52
        compress
        delaycompress
        notifempty
        create 640 $project adm
}
EOF
}


function gen_var() {
    project=${1:-""}
    [ -d $build_root/var/log/$project ]     || mkdir -p $build_root/var/log/$project
    [ -d $build_root/var/run/$project ]     || mkdir -p $build_root/var/run/$project
}