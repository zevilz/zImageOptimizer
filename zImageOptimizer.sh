#!/bin/bash
# Simple image optimizer for JPEG, PNG and GIF images.
# URL: https://github.com/zevilz/zImageOptimizer
# Author: Alexandr "zEvilz" Emshanov
# License: MIT
# Version: 0.7.0

# Define default vars
BINARY_PATHS="/bin/ /usr/bin/ /usr/local/bin/"
TMP_PATH="/tmp/"
TOOLS="jpegoptim jpegtran djpeg cjpeg pngcrush optipng pngout advpng gifsicle"
DEPS_DEBIAN="jpegoptim libjpeg-progs pngcrush optipng advancecomp gifsicle wget autoconf automake libtool make bc"
DEPS_REDHAT="jpegoptim libjpeg* pngcrush optipng advancecomp gifsicle wget autoconf automake libtool make bc"
GIT_URL="https://github.com/zevilz/zImageOptimizer"
TIME_MARKER_PATH=""
TIME_MARKER_NAME=".timeMarker"

# Min versions of distributions. Must be integer.
MIN_VERSION_DEBIAN=7
MIN_VERSION_UBUNTU=14
MIN_VERSION_FEDORA=24
MIN_VERSION_RHEL=6
MIN_VERSION_CENTOS=6

# Spacese separated supported versions of distributions.
SUPPORTED_VERSIONS_FREEBSD="10.3 10.4 11.1"

SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"

sayWait()
{
	local AMSURE
	[ -n "$1" ] && echo "$@" 1>&2
	read -n 1 -p "Press any key to continue..." AMSURE
	echo "" 1>&2
}
cdAndCheck()
{
	cd "$1" 2>/dev/null
	if ! [ "$(pwd)" = "$1" ] ; then
		if [ -z "$2" ] ; then
			echo "Can't get up in a directory $1. Exiting..." 1>&2
		else
			echo "$2" 1>&2
		fi
		exit 1
	fi
}
checkDir()
{
	if ! [ -d "$1" ] ; then
		if [ -z "$2" ] ; then
			echo "Directory $1 not found. Exiting..." 1>&2
		else
			echo "$2" 1>&2
		fi
		exit 1
	fi
}
checkDirPermissions()
{
	cd "$1" 2>/dev/null
	touch checkDirPermissions 2>/dev/null
	if ! [ -f "$1/checkDirPermissions" ] ; then
		if [ -z "$2" ] ; then
			echo "Current user have no permissions to directory $1. Exiting..." 1>&2
		else
			echo "$2" 1>&2
		fi
		exit 1
	else
		rm "$1/checkDirPermissions"
	fi
}
checkParm()
{
	if [ -z "$1" ] ; then
		echo "$2" 1>&2
		exit 1
	fi
}
installDeps()
{
	PLATFORM="unknown"
	PLATFORM_ARCH="unknown"
	PLATFORM_SUPPORT=0
	if [[ "$OSTYPE" == "linux-gnu" ]]; then
		PLATFORM="linux"
		PLATFORM_DISTRIBUTION="unknown"
		PLATFORM_VERSION="unknown"
		PLATFORM_PKG="unknown"

		if [ $(uname -m) == 'x86_64' ]; then
			PLATFORM_ARCH=64
		else
			PLATFORM_ARCH=32
		fi

		# First test against Fedora / RHEL / CentOS / generic Redhat derivative
		if [ -r /etc/rc.d/init.d/functions ]; then

			source /etc/rc.d/init.d/functions
			[ zz`type -t passed 2>/dev/null` == "zzfunction" ] && PLATFORM_PKG="redhat"
			PLATFORM_DISTRIBUTION=$(cat /etc/redhat-release | cut -d ' ' -f1)

			if [ $PLATFORM_DISTRIBUTION == "Fedora" ]
			then
				PLATFORM_VERSION=$(grep -oE '[0-9]+' /etc/redhat-release)
				if [ $PLATFORM_VERSION -ge $MIN_VERSION_FEDORA ]
				then
					PLATFORM_SUPPORT=1
				fi
			fi

			if [ $PLATFORM_DISTRIBUTION == "Red" ]
			then
				RHEL_RECHECK=$(cat /etc/redhat-release | cut -d ' ' -f1-4)
				if [ "$RHEL_RECHECK" == "Red Hat Enterprise Linux" ]
				then
					PLATFORM_DISTRIBUTION="RHEL"
					PLATFORM_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | cut -d '.' -f1)
					if [ $PLATFORM_VERSION -ge $MIN_VERSION_RHEL ]
					then
						PLATFORM_SUPPORT=1
					fi
				fi
			fi

			if [ $PLATFORM_DISTRIBUTION == "CentOS" ]
			then
				PLATFORM_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | cut -d '.' -f1)
				if [ $PLATFORM_VERSION -ge $MIN_VERSION_CENTOS ]
				then
					PLATFORM_SUPPORT=1
				fi
			fi

		# Then test against SUSE (must be after Redhat,
		# I've seen rc.status on Ubuntu I think? TODO: Recheck that)
#		elif [ -r /etc/rc.status ]; then
#			source /etc/rc.status
#			[ zz`type -t rc_reset 2>/dev/null` == "zzfunction" ] && PLATFORM_PKG="suse"

		# Then test against Debian, Ubuntu and friends
		elif [ -r /lib/lsb/init-functions ]; then

			source /lib/lsb/init-functions
			[ zz`type -t log_begin_msg 2>/dev/null` == "zzfunction" ] && PLATFORM_PKG="debian"
			PLATFORM_DISTRIBUTION=$(lsb_release -i | cut -d ':' -f2 | sed 's/\s//')
			PLATFORM_VERSION=$(lsb_release -r | cut -d ':' -f2 | sed 's/\s//' | sed 's/\..*//')

			if [ $PLATFORM_DISTRIBUTION == "Debian" ]
			then
				if [ $PLATFORM_VERSION -ge $MIN_VERSION_DEBIAN ]
				then
					PLATFORM_SUPPORT=1
				fi
			fi

			if [ $PLATFORM_DISTRIBUTION == "Ubuntu" ]
			then
				if [ $PLATFORM_VERSION -ge $MIN_VERSION_UBUNTU ]
				then
					PLATFORM_SUPPORT=1
				fi
			fi

		# Then test against Gentoo
#		elif [ -r /etc/init.d/functions.sh ]; then
#			source /etc/init.d/functions.sh
#			[ zz`type -t ebegin 2>/dev/null` == "zzfunction" ] && PLATFORM_PKG="gentoo"

		# For Slackware we currently just test if /etc/slackware-version exists
		# and isn't empty (TODO: Find a better way :)
#		elif [ -s /etc/slackware-version ]; then
#			PLATFORM_PKG="slackware"
		fi

#	elif [[ "$OSTYPE" == "darwin"* ]]; then
#		PLATFORM="macos"

	elif [[ "$OSTYPE" == "FreeBSD"* ]]; then

		PLATFORM="freebsd"
		PLATFORM_PKG="pkg"
		PLATFORM_DISTRIBUTION="FreeBSD"

		PLATFORM_ARCH=$(getconf LONG_BIT)

		PLATFORM_VERSION=$(freebsd-version | cut -d '-' -f1)
		SUPPORTED_VERSIONS_FREEBSD_ARRAY=($SUPPORTED_VERSIONS_FREEBSD)
		for v in "${!SUPPORTED_VERSIONS_FREEBSD_ARRAY[@]}" ; do
			if [ $PLATFORM_VERSION == "${SUPPORTED_VERSIONS_FREEBSD_ARRAY[$v]}" ]
			then
				PLATFORM_SUPPORT=1
			fi
		done

	fi

	if [ $DEBUG == 1 ]
	then
		echo "Platform info:"
		echo
		echo "PLATFORM: $PLATFORM"
		echo "PLATFORM_PKG: $PLATFORM_PKG"
		echo "PLATFORM_DISTRIBUTION $PLATFORM_DISTRIBUTION"
		echo "PLATFORM_ARCH: $PLATFORM_ARCH"
		echo "PLATFORM_VERSION: $PLATFORM_VERSION"
		echo "PLATFORM_SUPPORT: $PLATFORM_SUPPORT"
		echo
		sayWait
	fi

	if [ $PLATFORM_SUPPORT == 1 ]
	then
		echo "Installing dependences..."

		CUR_USER=$(whoami)
		if [ $CUR_USER == "root" ]
		then
			SUDO=""
		else
			SUDO="sudo"
		fi

		if [ $PLATFORM == "linux" ]
		then
			if [ $PLATFORM_PKG == "debian" ]
			then
				$SUDO apt-get update
				$SUDO apt-get install $DEPS_DEBIAN -y

			elif [ $PLATFORM_PKG == "redhat" ]
			then

				if [ $PLATFORM_DISTRIBUTION == "Fedora" ]
				then
					$SUDO dnf install epel-release -y
					$SUDO dnf install $DEPS_REDHAT -y
				elif [ $PLATFORM_DISTRIBUTION == "RHEL" ]
				then
					$SUDO yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$PLATFORM_VERSION.noarch.rpm -y
					echo
					echo -n "Enabling rhel-$PLATFORM_VERSION-server-optional-rpms repository..."
					$SUDO subscription-manager repos --enable rhel-$PLATFORM_VERSION-server-optional-rpms
					$SUDO yum install $DEPS_REDHAT -y
				else
					$SUDO yum install epel-release -y
					$SUDO yum install $DEPS_REDHAT -y
				fi

				if [[ $PLATFORM_DISTRIBUTION == "CentOS" && $PLATFORM_VERSION -eq 6 || $PLATFORM_DISTRIBUTION == "RHEL" && $PLATFORM_VERSION -eq 6 ]]
				then
					for p in "${!BINARY_PATHS_ARRAY[@]}" ; do
						if [ -f "${BINARY_PATHS_ARRAY[$p]}pngcrush" ]
						then
							ISSET_pngcrush=1
						fi
					done
					if [ $ISSET_pngcrush == 0 ]
					then
						wget https://downloads.sourceforge.net/project/pmt/pngcrush/old-versions/1.8/1.8.0/pngcrush-1.8.0.tar.gz
						tar -zxvf pngcrush-1.8.0.tar.gz
						rm pngcrush-1.8.0.tar.gz
						cd pngcrush-1.8.0
						make
						$SUDO cp pngcrush /bin/
						cd ../
						rm -rf pngcrush-1.8.0
					fi

					for p in "${!BINARY_PATHS_ARRAY[@]}" ; do
						if [ -f "${BINARY_PATHS_ARRAY[$p]}advpng" ]
						then
							ISSET_advpng=1
						fi
					done
					if [ $ISSET_advpng == 0 ]
					then
						$SUDO yum install zlib-devel gcc-c++ -y
						wget https://github.com/amadvance/advancecomp/releases/download/v2.0/advancecomp-2.0.tar.gz
						tar -zxvf advancecomp-2.0.tar.gz
						rm advancecomp-2.0.tar.gz
						cd advancecomp-2.0
						./configure
						make
						$SUDO make install
						cd ../
						rm -rf advancecomp-2.0
					fi
				fi
			fi

	#		for p in "${!BINARY_PATHS_ARRAY[@]}" ; do
	#			if [ -f "${BINARY_PATHS_ARRAY[$p]}djpeg" ]
	#			then
	#				ISSET_djpeg=1
	#			fi
	#		done
	#		for p in "${!BINARY_PATHS_ARRAY[@]}" ; do
	#			if [ -f "${BINARY_PATHS_ARRAY[$p]}cjpeg" ]
	#			then
	#				ISSET_cjpeg=1
	#			fi
	#		done

	#		if [[ $ISSET_djpeg == 0 || $ISSET_cjpeg == 0 ]]
	#		then
	#			git clone https://github.com/mozilla/mozjpeg.git
	#			cd mozjpeg/
	#			autoreconf -fiv
	#			./configure
	#			if [ $PLATFORM_PKG == "debian" ]
	#			then
	#				make deb
	#				$SUDO dpkg -i mozjpeg_*.deb
	#			else
	#				make
	#				$SUDO make install
	#			fi
	#			cd ../
	#			rm -rf mozjpeg
	#		fi

			if [[ $ISSET_pngout == 0 ]]
			then
				wget http://static.jonof.id.au/dl/kenutils/pngout-20150319-linux.tar.gz
				tar -xf pngout-20150319-linux.tar.gz
				rm pngout-20150319-linux.tar.gz
				if [ $PLATFORM_ARCH == 64 ]
				then
					$SUDO cp pngout-20150319-linux/x86_64/pngout /bin/pngout
				else
					$SUDO cp pngout-20150319-linux/i686/pngout /bin/pngout
				fi
				rm -rf pngout-20150319-linux
			fi

		elif [ $PLATFORM == "freebsd" ]
		then

#			for p in "${!BINARY_PATHS_ARRAY[@]}" ; do
#				if [ -f "${BINARY_PATHS_ARRAY[$p]}git" ]
#				then
#					ISSET_git=1
#				else
#					ISSET_git=0
#				fi
#			done
#			if [[ $ISSET_git == 0 ]]
#			then
#				cd /usr/ports/devel/git/
#				make BATCH=yes install clean
#			fi

			for p in "${!BINARY_PATHS_ARRAY[@]}" ; do
				if [ -f "${BINARY_PATHS_ARRAY[$p]}wget" ]
				then
					ISSET_wget=1
				else
					ISSET_wget=0
				fi
			done
			if [[ $ISSET_wget == 0 ]]
			then
				cd /usr/ports/ftp/wget/
				make BATCH=yes install clean
			fi

			if [[ $ISSET_jpegoptim == 0 ]]
			then
				cd /usr/ports/graphics/jpegoptim/
				make BATCH=yes install clean
			fi

			if [[ $ISSET_djpeg == 0 || $ISSET_cjpeg == 0 || $ISSET_jpegtran == 0 ]]
			then
				cd /usr/ports/graphics/jpeg/
				make BATCH=yes install clean
			fi

			if [[ $ISSET_pngcrush == 0 ]]
			then
				cd /usr/ports/graphics/pngcrush/
				make BATCH=yes install clean
			fi

			if [[ $ISSET_optipng == 0 ]]
			then
				cd /usr/ports/graphics/optipng/
				make BATCH=yes install clean
			fi

			if [[ $ISSET_advpng == 0 ]]
			then
				cd /usr/ports/archivers/advancecomp/
				make BATCH=yes install clean
			fi

			if [[ $ISSET_gifsicle == 0 ]]
			then
				cd /usr/ports/graphics/gifsicle/
				make BATCH=yes install clean
			fi

			if [[ $ISSET_pngout == 0 ]]
			then
				cd ~
				wget http://static.jonof.id.au/dl/kenutils/pngout-20150319-bsd.tar.gz
				tar -xf pngout-20150319-bsd.tar.gz
				rm pngout-20150319-bsd.tar.gz
				if [ $PLATFORM_ARCH == 64 ]
				then
					$SUDO cp pngout-20150319-bsd/amd64/pngout /bin/pngout
				else
					$SUDO cp pngout-20150319-bsd/i686/pngout /bin/pngout
				fi
				rm -rf pngout-20150319-bsd
			fi

		fi

	else
		echo "Your platform not supported! Please install dependaces manually."
		echo "Info: $GIT_URL"
		echo
	fi
}
usage()
{
	echo
	echo "Usage: bash $0 [options]"
	echo
	echo "Simple image optimizer for JPEG, PNG and GIF images."
	echo
	echo "Options:"
	echo
	echo "	-h, --help         Shows this help."
	echo
	echo "	-p, --path [dir]   Specify input directory with or without slash "
	echo "	                   in the end of path."
	echo
	echo "	-q, --quiet        Execute script without any questions and users "
	echo "	                   actions."
	echo
	echo "	-c, --check-only   Only check tools with an opportunity to install "
	echo "	                   dependences. All parameters will be ignored "
	echo "	                   with this parameter."
	echo
	echo "	-t, --time         Period for which to look for files by last "
	echo "	                   modified time. Must be set in minutes (10m, 30m "
	echo "	                   etc.) or hours (1h, 10h etc.) or days (1d, 30d "
	echo "	                   etc.). It is impossible to use with "
	echo "	                   -n|--new-only option. (test)"
	echo
	echo "	-n, --new-only     Find only new images basis on special time "
	echo "	                   marker file which created/modified in the end "
	echo "	                   of last optimizing. Recommended for cron usage "
	echo "	                   to avoid repeated optimization already "
	echo "	                   optimized files. Time marker automatically "
	echo "	                   creates with first script running with this "
	echo "	                   option. By default time marker creates in "
	echo "	                   working directory which set as inpit path. "
	echo "	                   It is impossible to use with -t|--time option. "
	echo "	                   (test)"
	echo
	echo "	-m, --time-marker  Custom path/name of time marker file. Must be "
	echo "	                   name of file (only for change time marker name) "
	echo "	                   or full path for custom marker in custom "
	echo "	                   directory. Working only with -n|--new-only "
	echo "	                   option. (test)"
	echo
}
getTimeMarkerPath()
{
	TIME_MARKER_PATH=$(echo "$TIME_MARKER_PATH" | sed 's/\/$//')
	if [ -z $TIME_MARKER ]
	then
		if [ -z $TIME_MARKER_PATH ]
		then
			echo "$DIR_PATH/$TIME_MARKER_NAME"
		else
			echo "$TIME_MARKER_PATH/$TIME_MARKER_NAME"
		fi
	else
		if [[ $TIME_MARKER == *\/* ]]
		then
			echo "$TIME_MARKER"
		else
			if [ -z $TIME_MARKER_PATH ]
			then
				echo "$DIR_PATH/$TIME_MARKER"
			else
				echo "$TIME_MARKER_PATH/$TIME_MARKER"
			fi
		fi
	fi
}
checkTimeMarkerPermissions()
{
	TIME_MARKER_MODIFIED=$(date -r "$1" +%s)
	touch -m "$1" 2>/dev/null
	TIME_MARKER_MODIFIED_NEW=$(date -r "$1" +%s)
	if [ $TIME_MARKER_MODIFIED -eq $TIME_MARKER_MODIFIED_NEW ]
	then
		echo "Current user have no permissions to modify time marker. Exiting..." 1>&2
		exit 1
	else
		if date --version >/dev/null 2>/dev/null
		then
			touch -t $(date '+%Y%m%d%H%M.%S' -d @$TIME_MARKER_MODIFIED) "$1" 2>/dev/null # GNU version of date
		else
			touch -t $(date -r $TIME_MARKER_MODIFIED +%Y%m%d%H%M.%S) "$1" 2>/dev/null # Non GNU version of date
		fi
	fi
}
updateTimeMarker()
{
	if [ $NEW_ONLY -eq 1 ]
	then
		sleep 1
		touch -m "$TIME_MARKER_FULL_PATH" >/dev/null
		echo
		if [ $TIME_MARKER_ISSET -eq 1 ]
		then
			echo "Time marker updated."
		else
			echo "Time marker created."
		fi
	fi
}
optimJpegoptim()
{
	jpegoptim --strip-all "$1" > /dev/null
}
optimJpegtran()
{
	jpegtran -progressive -copy none -optimize "$1" > /dev/null
}
optimMozjpeg()
{
	djpeg -outfile $TMP_PATH"$(basename "$1")" "$1" > /dev/null
	cjpeg -optimize -progressive -outfile "$1" $TMP_PATH"$(basename "$1")" > /dev/null
	rm $TMP_PATH"$(basename "$1")"
}
optimConvert()
{
	convert $1 -background Black -alpha Background $1 > /dev/null
}
optimPngcrush()
{
	IMAGE="$1"
	IMAGE_DIR=$(dirname "$IMAGE")
	cd "$IMAGE_DIR"
	pngcrush -rem gAMA -rem cHRM -rem iCCP -rem sRGB -brute -l 9 -reduce -q -s -ow "$IMAGE" > /dev/null
}
optimOptipng()
{
	OPTIPNG_V=$(optipng -v | head -n1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | cut -d '.' -f2)
	if [ $OPTIPNG_V -ge 7 ]
	then
		optipng -strip all -o7 -q "$1" > /dev/null
	else
		optipng -o7 -q "$1" > /dev/null
	fi
}
optimPngout()
{
	pngout -q -y -k0 -s0 "$1" > /dev/null
}
optimAdvpng()
{
	advpng -z -4 "$1" > /dev/null
}
optimGifsicle()
{
	gifsicle --optimize=3 -b "$1" > /dev/null
	#gifsicle --optimize=3 --lossy=30 -b "$IMAGE" # for lossy optimize
}
readableSize()
{
	if [ $1 -ge 1000000000 ]
	then
		echo -n $(echo "scale=1; $1/1024/1024/1024" | bc | sed 's/^\./0./')"Gb"
	elif [ $1 -ge 1000000 ]
	then
		echo -n $(echo "scale=1; $1/1024/1024" | bc | sed 's/^\./0./')"Mb"
	else
		echo -n $(echo "scale=1; $1/1024" | bc | sed 's/^\./0./')"Kb"
	fi
}

# Define inner default vars. Don't change them!
DEBUG=0
HELP=0
NO_ASK=0
CHECK_ONLY=0
PERIOD=0
NEW_ONLY=0
TIME_MARKER=""
PARAMS_NUM=$#

while [ 1 ] ; do
	if [ "${1#--path=}" != "$1" ] ; then
		DIR_PATH="${1#--path=}"
	elif [ "$1" = "-p" ] ; then
		shift ; DIR_PATH="$1"

	elif [ "${1#--time=}" != "$1" ] ; then
		PERIOD="${1#--time=}"
	elif [ "$1" = "-t" ] ; then
		shift ; PERIOD="$1"

	elif [ "${1#--time-marker=}" != "$1" ] ; then
		TIME_MARKER="${1#--time-marker=}"
	elif [ "$1" = "-m" ] ; then
		shift ; TIME_MARKER="$1"

	elif [[ "$1" = "--help" || "$1" = "-h" ]] ; then
		HELP=1

	elif [[ "$1" = "--quiet" || "$1" = "-q" ]] ; then
		NO_ASK=1

	elif [[ "$1" = "--check-only" || "$1" = "-c" ]] ; then
		CHECK_ONLY=1

	elif [[ "$1" = "--new-only" || "$1" = "-n" ]] ; then
		NEW_ONLY=1

	elif [[ "$1" = "--debug" || "$1" = "-d" ]] ; then
		DEBUG=1

	elif [ -z "$1" ] ; then
		break
	else
		echo
		echo "Unknown key detected!" 1>&2
		usage
		exit 1
	fi
	shift
done

if [[ $HELP == 1 || $PARAMS_NUM == 0 ]]
then
	usage
	exit 1
fi

if [ $CHECK_ONLY -eq 0 ]
then
	DIR_PATH=$(echo "$DIR_PATH" | sed 's/\/$//')
	checkParm "$DIR_PATH" "Path to files not set. Exiting..."
	checkDir "$DIR_PATH"
	cdAndCheck "$DIR_PATH"
	checkDirPermissions "$DIR_PATH"

	if [[ $PERIOD != 0 && $NEW_ONLY -gt 0 ]]
	then
		echo "It is impossible to use parameters -t(--time) and -n(--new-only) together. Set only one of it. Exiting..."
		exit 1
	fi

	if [ $PERIOD != 0 ]
	then
		if ! [[ $PERIOD =~ ^-?[0-9]+(m|h|d)$ ]]
		then
			echo "Wrong format of period. Exiting..."
			exit 1
		fi

		PERIOD_VAL=$(echo "$PERIOD" | sed 's/.$//')
		if [ $(echo "$PERIOD" | sed 's/[^mhd]*//') == "m" ]
		then
			PERIOD_UNIT="m"
			PERIOD_UNIT_NAME="minute(s)"
			FIND_INCLUDE="-mmin -$PERIOD_VAL"
		elif [ $(echo "$PERIOD" | sed 's/[^mhd]*//') == "h" ]
		then
			PERIOD_UNIT="h"
			PERIOD_UNIT_NAME="hour(s)"
			let PERIOD_VAL_H=$PERIOD_VAL*60
			FIND_INCLUDE="-mmin -$PERIOD_VAL_H"
		elif [ $(echo "$PERIOD" | sed 's/[^mhd]*//') == "d" ]
		then
			PERIOD_UNIT="d"
			PERIOD_UNIT_NAME="day(s)"
			FIND_INCLUDE="-mtime -$PERIOD_VAL"
		fi
		echo
		echo "Detecting find images modified last $PERIOD_VAL $PERIOD_UNIT_NAME."
	elif [ $NEW_ONLY -eq 1 ]
	then
		echo
		echo "Detecting using time marker. Will be find images newer than time marker."
		echo -n "Checking marker..."
		TIME_MARKER_FULL_PATH=$(getTimeMarkerPath)
		TIME_MARKER_FULL_PATH_DIR=$(dirname "$TIME_MARKER_FULL_PATH")
		TIME_MARKER_FULL_PATH_NAME=$(basename "$TIME_MARKER_FULL_PATH")
		checkDir "$TIME_MARKER_FULL_PATH_DIR" "Directory for marker not found. Exiting..."
		cdAndCheck "$TIME_MARKER_FULL_PATH_DIR" "Can't get up in a directory for marker. Exiting..."
		checkDirPermissions "$TIME_MARKER_FULL_PATH_DIR" "Current user have no permissions to directory for marker. Exiting..."
		if [ -f "$TIME_MARKER_FULL_PATH" ]
		then
			checkTimeMarkerPermissions "$TIME_MARKER_FULL_PATH"
			$SETCOLOR_SUCCESS
			echo -n "[FOUND]"
			$SETCOLOR_NORMAL
			FIND_INCLUDE="-newer $TIME_MARKER_FULL_PATH"
			TIME_MARKER_ISSET=1
		else
			$SETCOLOR_FAILURE
			echo "[NOT FOUND]"
			$SETCOLOR_NORMAL
			echo -n "Time marker will be created after optimizing."
			FIND_INCLUDE=""
			TIME_MARKER_ISSET=0
		fi
		if [ $DEBUG -eq 1 ]
		then
			echo -n " ($TIME_MARKER_FULL_PATH)"
		fi
		echo
	else
		FIND_INCLUDE=""
	fi
fi

BINARY_PATHS_ARRAY=($BINARY_PATHS)
TOOLS_ARRAY=($TOOLS)
ALL_FOUND=1

echo
echo -n "Checking tools"
if [ $DEBUG == 1 ]
then
	echo -n " in $BINARY_PATHS"
fi
echo "..."

for t in "${!TOOLS_ARRAY[@]}" ; do
	FOUND=0
	echo -n ${TOOLS_ARRAY[$t]}"..."
	for p in "${!BINARY_PATHS_ARRAY[@]}" ; do
		if [ -f "${BINARY_PATHS_ARRAY[$p]}${TOOLS_ARRAY[$t]}" ]
		then
			FOUND=1
			TOOL_PATH="${BINARY_PATHS_ARRAY[$p]}${TOOLS_ARRAY[$t]}"
		fi
	done
	if [ $FOUND == 1 ]
	then
		$SETCOLOR_SUCCESS
		echo -n "[FOUND]"
		$SETCOLOR_NORMAL
		if [ $DEBUG == 1 ]
		then
			echo -n " $TOOL_PATH"
		fi
		echo
		tool=${TOOLS_ARRAY[$t]}
		declare ISSET_$tool=1
	else
		$SETCOLOR_FAILURE
		echo "[NOT FOUND]"
		$SETCOLOR_NORMAL
		ALL_FOUND=0
		tool=${TOOLS_ARRAY[$t]}
		declare ISSET_$tool=0
	fi
done

echo

if [ $ALL_FOUND == 1 ]
then
	echo "All tools found"
	echo
	if [[ $NO_ASK == 0 && $CHECK_ONLY == 0 ]]
	then
		sayWait
	fi
	if [ $CHECK_ONLY == 1 ]
	then
		exit 0
	fi
else
	echo "One or more tools not found"
	echo
	if [ $NO_ASK == 0 ]
	then
		echo "Please Select:"
		echo
		if [ $CHECK_ONLY == 0 ]
		then
			echo "1. Continue (default)"
			echo "2. Install dependences and exit"
			echo "0. Exit"
			echo
			echo -n "Enter selection [1] > "
		else
			echo "1. Install dependences and exit"
			echo "0. Exit (default)"
			echo
			echo -n "Enter selection [0] > "
		fi
		if [ $CHECK_ONLY == 0 ]
		then
			read item
			case "$item" in
				1) echo
					;;
				0) echo
					echo "Exiting..."
					exit 0
					;;
				2) echo
					installDeps
					echo "Exiting..."
					exit 0
					;;
				*) echo 
					;;
			esac
		else
			read item
			case "$item" in
				0) echo
					echo "Exiting..."
					exit 0
					;;
				1) echo
					installDeps
					echo "Exiting..."
					exit 0
					;;
				*) echo
					echo "Exiting..."
					exit 0
					;;
			esac
		fi
	fi
fi

IMAGES=`\
find "$DIR_PATH" $FIND_INCLUDE \( \
-name '*.jpg' -or \
-name '*.jpeg' -or \
-name '*.gif' -or \
-name '*.JPG' -or \
-name '*.JPEG' -or \
-name '*.GIF' -or \
-name '*.png' -or \
-name '*.PNG' \
\)`

if ! [ -z "$IMAGES" ]
then
	echo "Optimizing..."

	INPUT=0
	OUTPUT=0
	SAVED_SIZE=0

	echo "$IMAGES" | ( while read IMAGE ; do
		echo -n "$IMAGE"
		echo -n '...'
		SIZE_BEFORE=$(wc -c "$IMAGE" | awk '{print $1}')
		SIZE_BEFORE_SCALED=$(echo "scale=1; $SIZE_BEFORE/1024" | bc | sed 's/^\./0./')
		INPUT=$(echo "$INPUT+$SIZE_BEFORE" | bc)

		EXT=${IMAGE##*.}

		if [[ $EXT == "jpg" || $EXT == "jpeg" || $EXT == "JPG" || $EXT == "JPEG" ]]
		then
			echo -n " "

			if [ $ISSET_jpegoptim == 1 ]
			then
				optimJpegoptim "$IMAGE"
			fi

			if [ $ISSET_jpegtran == 1 ]
			then
				optimJpegtran "$IMAGE"
			fi

			if [[ $ISSET_djpeg == 1 && $ISSET_cjpeg == 1 ]]
			then
				optimMozjpeg "$IMAGE"
			fi

		elif [[ $EXT == "png" || $EXT == "PNG" ]]
		then
			echo -n " "

	#		if [ $ISSET_convert == 1 ]
	#		then
	#			optimConvert "$IMAGE"
	#		fi

			if [ $ISSET_pngcrush == 1 ]
			then
				optimPngcrush "$IMAGE"
			fi

			if [ $ISSET_optipng == 1 ]
			then
				optimOptipng "$IMAGE"
			fi

			if [ $ISSET_pngout == 1 ]
			then
				optimPngout "$IMAGE"
			fi

			if [ $ISSET_advpng == 1 ]
			then
				optimAdvpng "$IMAGE"
			fi
		elif [[ $EXT == "gif" || $EXT == "GIF" ]]
		then
			if [ $ISSET_gifsicle == 1 ]
			then
				optimGifsicle "$IMAGE"
			fi
		fi

		SIZE_AFTER=$(wc -c "$IMAGE" | awk '{print $1}')
		SIZE_AFTER_SCALED=$(echo "scale=1; $SIZE_AFTER/1024" | bc | sed 's/^\./0./')
		OUTPUT=$(echo "$OUTPUT+$SIZE_AFTER" | bc)
		if [ $(echo "scale=0; $SIZE_BEFORE/100" | bc) -le $(echo "scale=0; $SIZE_AFTER/100" | bc) ]
		then
			$SETCOLOR_FAILURE
			echo -n "[NOT OPTIMIZED]"
			$SETCOLOR_NORMAL
			echo -n " ${SIZE_AFTER_SCALED}Kb"
		else
			$SETCOLOR_SUCCESS
			echo -n "[OPTIMIZED]"
			$SETCOLOR_NORMAL
			echo -n " ${SIZE_BEFORE_SCALED}Kb -> ${SIZE_AFTER_SCALED}Kb"
			SIZE_DIFF=$(echo "$SIZE_BEFORE-$SIZE_AFTER" | bc)
			SAVED_SIZE=$(echo "$SAVED_SIZE+$SIZE_DIFF" | bc)
		fi
		echo
	done

	echo
	echo -n "Input: "
	readableSize $INPUT
	echo

	echo -n "Output: "
	readableSize $OUTPUT
	echo

	echo -n "You save: "
	readableSize $SAVED_SIZE
	echo " / $(echo "scale=2; 100-$OUTPUT*100/$INPUT" | bc | sed 's/^\./0./')%"
	)
	updateTimeMarker
else
	echo "No input images found."
fi

echo
exit 0
