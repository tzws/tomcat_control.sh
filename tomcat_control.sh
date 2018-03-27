#!/bin/sh
#
# this file is based on ubuntu's /etc/init.d/tomcat8
#
# /etc/init.d/tomcat8 -- startup script for the Tomcat 8 servlet engine
#
# Written by Miquel van Smoorenburg <miquels@cistron.nl>.
# Modified for Debian GNU/Linux	by Ian Murdock <imurdock@gnu.ai.mit.edu>.
# Modified for Tomcat by Stefan Gybas <sgybas@debian.org>.
# Modified for Tomcat6 by Thierry Carrez <thierry.carrez@ubuntu.com>.
# Modified for Tomcat7 by Ernesto Hernandez-Novich <emhn@itverx.com.ve>.
# Additional improvements by Jason Brittain <jason.brittain@mulesoft.com>.
#
### BEGIN INIT INFO
# Provides:          tomcat8
# Required-Start:    $local_fs $remote_fs $network
# Required-Stop:     $local_fs $remote_fs $network
# Should-Start:      $named
# Should-Stop:       $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start Tomcat.
# Description:       Start the Tomcat servlet engine.
### END INIT INFO


# use tomcat_dir/bin as start directory
# CATALINA_HOME=/usr/share/$NAME
CWD=$(realpath $0)

CWD=$(dirname $CWD)

CWD=$(dirname $CWD)


# Directory for per-instance configuration files and webapps
CATALINA_HOME=$CWD
CATALINA_BASE=$CWD
WORKING_DIR=$(basename $CWD)


set -e

PATH=/bin:/usr/bin:/sbin:/usr/sbin
NAME=tomcat
DEFAULT=./config.sh
JVM_TMP=/tmp/tomcat-$WORKING_DIR

DESC="Tomcat servlet engine in ${CATALINA_BASE}"

# don't need root privilege
# if [ `id -u` -ne 0 ]; then
#     echo "You need root privileges to run this script"
#     exit 1
# fi

# Make sure tomcat is started with system locale
if [ -e /etc/default/locale -a -r /etc/default/locale ]; then
	. /etc/default/locale
	export LANG
elif [ -e /etc/locale.conf -a -r /etc/locale.conf ]; then
    . /etc/locale.conf
	export LANG
fi

# The following variables can be overwritten in $DEFAULT

# Run Tomcat 8 as this user ID and group ID
# TOMCAT8_USER=tomcat8
# TOMCAT8_GROUP=tomcat8
TOMCAT8_USER=$(whoami)
TOMCAT8_GROUP=$(whoami)

# this is a work-around until there is a suitable runtime replacement
# for dpkg-architecture for arch:all packages
# this function sets the variable JDK_DIRS

# let the user set JAVA_HOME variable, other than guess the JDK dir
if [ -z "${JAVA_HOME-}" ]; then
    echo "JAVA_HOME is not defined. exiting....";
    exit 1;
else

    if [ ! -d $JAVA_HOME ]; then
        echo "$JAVA_HOME is not a directory. existing....";
        exit 1;
    else
        if [ ! -f $JAVA_HOME/bin/java ]; then
            echo "${JAVA_HOME}/bin/java does not exists. exiting....";
            exit 1;
        fi
    fi
fi

# Use the Java security manager? (yes/no)
TOMCAT8_SECURITY=no

# Default Java options
# Set java.awt.headless=true if JAVA_OPTS is not set so the
# Xalan XSL transformer can work without X11 display on JDK 1.4+
# It also looks like the default heap size of 64M is not enough for most cases
# so the maximum heap size is set to 128M
if [ -z "$JAVA_OPTS" ]; then
	JAVA_OPTS="-Djava.awt.headless=true -Xmx128M"
fi

# End of variables that can be overwritten in $DEFAULT


if [ ! -f "$CATALINA_HOME/bin/bootstrap.jar" ]; then
	echo "$NAME is not installed"
	exit 1
fi


#if [ -z "$CATALINA_TMPDIR" ]; then
	CATALINA_TMPDIR="$JVM_TMP"
#fi

# Set the JSP compiler if set in the tomcat8.default file
if [ -n "$JSP_COMPILER" ]; then
	JAVA_OPTS="$JAVA_OPTS -Dbuild.compiler=\"$JSP_COMPILER\""
fi

SECURITY=""
if [ "$TOMCAT8_SECURITY" = "yes" ]; then
	SECURITY="-security"
fi

# the main purpose of this script is to set the CATALINA_PID 
# Define other required variables
# CATALINA_PID="/var/run/$NAME.pid"
CATALINA_PID="$CATALINA_BASE/conf/${NAME}_pid.pid"
CATALINA_SH="$CATALINA_HOME/bin/catalina.sh"

# Look for Java Secure Sockets Extension (JSSE) JARs
if [ -z "${JSSE_HOME}" -a -r "${JAVA_HOME}/jre/lib/jsse.jar" ]; then
    JSSE_HOME="${JAVA_HOME}/jre/"
fi

catalina_sh() {
	# Escape any double quotes in the value of JAVA_OPTS
	JAVA_OPTS="$(echo $JAVA_OPTS | sed 's/\"/\\\"/g')"

	AUTHBIND_COMMAND=""
	if [ "$AUTHBIND" = "yes" -a "$1" = "start" ]; then
		AUTHBIND_COMMAND="/usr/bin/authbind --deep /bin/bash -c "
	fi

	# Define the command to run Tomcat's catalina.sh as a daemon
	# set -a tells sh to export assigned variables to spawned shells.
	TOMCAT_SH="set -a; JAVA_HOME=\"$JAVA_HOME\"; \
		CATALINA_HOME=\"$CATALINA_HOME\"; \
		CATALINA_BASE=\"$CATALINA_BASE\"; \
		JAVA_OPTS=\"$JAVA_OPTS\"; \
		CATALINA_PID=\"$CATALINA_PID\"; \
		CATALINA_TMPDIR=\"$CATALINA_TMPDIR\"; \
		LANG=\"$LANG\"; JSSE_HOME=\"$JSSE_HOME\"; \
		cd \"$CATALINA_BASE\"; \
		\"$CATALINA_SH\" $@"


	if [ "$AUTHBIND" = "yes" -a "$1" = "start" ]; then
		TOMCAT_SH="'$TOMCAT_SH'"
	fi

	# Run the catalina.sh script as a daemon
	set +e
	if [ ! -f "$CATALINA_BASE"/logs/catalina.out ]; then
		install -o $TOMCAT8_USER -g adm -m 644 /dev/null "$CATALINA_BASE"/logs/catalina.out
	fi
	#install -o $TOMCAT8_USER -g adm -m 644 /dev/null "$CATALINA_PID"

	cd $CATALINA_BASE 
	JAVA_HOME=$JAVA_HOME CATALINA_HOME=$CATALINA_HOME CATALINA_BASE=$CATALINA_BASE JAVA_OPTS="$JAVA_OPTS" CATALINA_PID=$CATALINA_PID CATALINA_TMPDIR=$CATALINA_TMPDIR LANG=$LANG JSSE_HOME=$JSSE_HOME $CATALINA_SH $@


	status="$?"
	set +a -e
	return $status
}

case "$1" in
  start)
	if [ -z "$JAVA_HOME" ]; then
		echo "no JDK or JRE found - please set JAVA_HOME"
		exit 1
	fi

	if [ ! -d "$CATALINA_BASE/conf" ]; then
		echo "invalid CATALINA_BASE: $CATALINA_BASE"
		exit 1
	fi

	echo "Starting $DESC" "$NAME"
    if [ ! -f $CATALINA_PID ]; then
	    echo "$CATALINA_PID does not exists"
    else
        xpid=$(cat $CATALINA_PID)
        ypid=$(ps ax | grep tomcat | grep $CATALINA_BASE | cut -d " " -f 2)
	if [ ! -z $yid ]; then
		if [ $xpid = $ypid ]; then
			echo "tomcat of $CATALINA_BASE already runnning. existing...";
			exit 0;
		fi
	fi
    fi

		# Regenerate POLICY_CACHE file
		umask 022
		# Remove / recreate JVM_TMP directory
		rm -rf "$JVM_TMP"
		mkdir "$JVM_TMP" || {
			echo "could not create JVM temporary directory"
			exit 1
		}
		# chown -h $TOMCAT8_USER "$JVM_TMP"

		catalina_sh start $SECURITY
		sleep 5

        if [ -r $CATALINA_PID ]; then
            xpid=$(cat $CATALINA_PID)

            # pid is not written into CATALINA_PID file
            if [ -z $xpid ]; then
                echo "pid is not written into CATALINA_PID file. exiting...."
                exit 1;
            fi

            ypid=$(ps ax | grep tomcat | grep $CATALINA_BASE | cut -d " " -f 2)
            if [ ! -z $pid ]; then
                echo "ypid is not null"

                if [ $xpid != $ypid ]; then
                    echo "tomcat of $CATALINA_BASE something went wrong, pid from ps and pid from $CATALINA_PID are different.";
                    exit 1;
                fi
            fi
        fi
	;;
  stop)
	echo "Stopping $DESC" "$NAME"

	set +e
	if [ -f "$CATALINA_PID" ]; then 

		catalina_sh stop -force
		if [ $? -eq 1 ]; then
			echo "$DESC is not running but pid file exists, cleaning up"
		elif [ $? -eq 3 ]; then
			PID="`cat $CATALINA_PID`"
			echo "Failed to stop $NAME  pid ${PID} "
			exit 1
		fi
		rm -f "$CATALINA_PID"
		rm -rf "$JVM_TMP"
	else
		echo "tomcat in ${CATALINA_BASE} not running"
	fi
	set -e
	;;
   status)
	set +e

    if [ -r $CATALINA_PID ]; then
        xpid=$(cat $CATALINA_PID)

        # pid is not written into CATALINA_PID file
        if [ -z $xpid ]; then
            echo "tomcat of $CATALINA_BASE pid file exists, but empty. exiting...."
            exit 1;
        fi

        ypid=$(ps ax | grep tomcat | grep $CATALINA_BASE | cut -d " " -f 2)
	if [ ! -z $pid ]; then
		if [ $xpid != $ypid ]; then
			echo "tomcat of $CATALINA_BASE something went wrong, pid from ps and pid from $CATALINA_PID are different.";
			exit 1;
		fi

	else
            echo "tomcat of $CATALINA_BASE is running with pid `cat $CATALINA_PID`"
	fi

    else
        echo "tomcat of $CATALINA_BASE not runing...."
        exit 3
    fi

	set -e
        ;;
  restart|force-reload)
	if [ -f "$CATALINA_PID" ]; then
		$0 stop -force
		sleep 1
	fi
	$0 start
	;;

  *)
	echo "Usage: $0 {start|stop|restart|force-reload|status}"
	exit 1
	;;
esac

exit 0

