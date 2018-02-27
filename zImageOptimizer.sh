#!/bin/bash
# Simple image optimizer for JPEG, PNG and GIF images.
# URL: https://github.com/zevilz/zImageOptimizer
# Author: Alexandr "zEvilz" Emshanov
# License: MIT
# Version: 0.9.2

# Define default vars
BINARY_PATHS="/bin /usr/bin /usr/local/bin"
TMP_PATH="/tmp"
TOOLS="jpegoptim jpegtran djpeg cjpeg pngcrush optipng pngout advpng gifsicle"
DEPS_DEBIAN="jpegoptim libjpeg-progs pngcrush optipng advancecomp gifsicle wget autoconf automake libtool make bc"
DEPS_REDHAT="jpegoptim libjpeg* pngcrush optipng advancecomp gifsicle wget autoconf automake libtool make bc"
DEPS_MACOS="jpegoptim libjpeg pngcrush optipng advancecomp gifsicle jonof/kenutils/pngout"
GIT_URL="https://github.com/zevilz/zImageOptimizer"
TIME_MARKER_PATH=""
TIME_MARKER_NAME=".timeMarker"

# Min versions of distributions. Must be integer.
MIN_VERSION_DEBIAN=7
MIN_VERSION_UBUNTU=14
MIN_VERSION_FEDORA=24
MIN_VERSION_RHEL=6
MIN_VERSION_CENTOS=6

# Min version MacOS (second digit; ex. 10.12.2 == 12).
MIN_VERSION_MACOS=10

# Spacese separated supported versions of distributions.
SUPPORTED_VERSIONS_FREEBSD="10.3 10.4 11.1"

if [ "Z$(ps o comm="" -p $(ps o ppid="" -p $$))" == "Zcron" -o \
     "Z$(ps o comm="" -p $(ps o ppid="" -p $(ps o ppid="" -p $$)))" == "Zcron" ]; then
	SETCOLOR_SUCCESS=
	SETCOLOR_FAILURE=
	SETCOLOR_NORMAL=
else
	SETCOLOR_SUCCESS="echo -en \\033[1;32m"
	SETCOLOR_FAILURE="echo -en \\033[1;31m"
	SETCOLOR_NORMAL="echo -en \\033[0;39m"
fi

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
	if ! [ "$(pwd)" = "$1" ]; then
		if [ -z "$2" ]; then
			echo "Can't get up in a directory $1. Exiting..." 1>&2
		else
			echo "$2" 1>&2
		fi
		exit 1
	fi
}

checkDir()
{
	if ! [ -d "$1" ]; then
		if [ -z "$2" ]; then
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
	if ! [ -f "$1/checkDirPermissions" ]; then
		if [ -z "$2" ]; then
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
	if [ -z "$1" ]; then
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

			if [ $PLATFORM_DISTRIBUTION == "Fedora" ]; then
				PLATFORM_VERSION=$(grep -oE '[0-9]+' /etc/redhat-release)
				if [ $PLATFORM_VERSION -ge $MIN_VERSION_FEDORA ]; then
					PLATFORM_SUPPORT=1
				fi
			fi

			if [ $PLATFORM_DISTRIBUTION == "Red" ]; then
				RHEL_RECHECK=$(cat /etc/redhat-release | cut -d ' ' -f1-4)
				if [ "$RHEL_RECHECK" == "Red Hat Enterprise Linux" ]; then
					PLATFORM_DISTRIBUTION="RHEL"
					PLATFORM_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | cut -d '.' -f1)
					if [ $PLATFORM_VERSION -ge $MIN_VERSION_RHEL ]; then
						PLATFORM_SUPPORT=1
					fi
				fi
			fi

			if [ $PLATFORM_DISTRIBUTION == "CentOS" ]; then
				PLATFORM_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | cut -d '.' -f1)
				if [ $PLATFORM_VERSION -ge $MIN_VERSION_CENTOS ]; then
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

			if [ $PLATFORM_DISTRIBUTION == "Debian" ]; then
				if [ $PLATFORM_VERSION -ge $MIN_VERSION_DEBIAN ]; then
					PLATFORM_SUPPORT=1
				fi
			fi

			if [ $PLATFORM_DISTRIBUTION == "Ubuntu" ]; then
				if [ $PLATFORM_VERSION -ge $MIN_VERSION_UBUNTU ]; then
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

	elif [[ "$OSTYPE" == "darwin"* ]]; then

		PLATFORM="macos"
		PLATFORM_PKG="dmg"
		PLATFORM_DISTRIBUTION="MacOS"

		PLATFORM_ARCH=$(getconf LONG_BIT)

		PLATFORM_VERSION="$(defaults read loginwindow SystemVersionStampAsString)"
		if [[ $(echo $PLATFORM_VERSION | cut -d '.' -f2) -ge $MIN_VERSION_MACOS ]]; then
			PLATFORM_SUPPORT=1
		fi

	elif [[ "$OSTYPE" == "FreeBSD"* ]]; then

		PLATFORM="freebsd"
		PLATFORM_PKG="pkg"
		PLATFORM_DISTRIBUTION="FreeBSD"

		PLATFORM_ARCH=$(getconf LONG_BIT)

		PLATFORM_VERSION=$(freebsd-version | cut -d '-' -f1)
		SUPPORTED_VERSIONS_FREEBSD_ARRAY=($SUPPORTED_VERSIONS_FREEBSD)
		for v in "${!SUPPORTED_VERSIONS_FREEBSD_ARRAY[@]}" ; do
			if [ $PLATFORM_VERSION == "${SUPPORTED_VERSIONS_FREEBSD_ARRAY[$v]}" ]; then
				PLATFORM_SUPPORT=1
			fi
		done

	fi

	if [ $DEBUG -eq 1 ]; then
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

	if [ $PLATFORM_SUPPORT -eq 1 ]; then
		echo "Installing dependences..."

		CUR_USER=$(whoami)
		if [ $CUR_USER == "root" ]; then
			SUDO=""
		else
			SUDO="sudo"
		fi

		if [ $PLATFORM == "linux" ]; then
			if [ $PLATFORM_PKG == "debian" ]; then
				$SUDO apt-get update
				$SUDO apt-get install $DEPS_DEBIAN -y

			elif [ $PLATFORM_PKG == "redhat" ]; then

				if [ $PLATFORM_DISTRIBUTION == "Fedora" ]; then
					$SUDO dnf install epel-release -y
					$SUDO dnf install $DEPS_REDHAT -y
				elif [ $PLATFORM_DISTRIBUTION == "RHEL" ]; then
					$SUDO yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$PLATFORM_VERSION.noarch.rpm -y
					echo
					echo -n "Enabling rhel-$PLATFORM_VERSION-server-optional-rpms repository..."
					$SUDO subscription-manager repos --enable rhel-$PLATFORM_VERSION-server-optional-rpms
					$SUDO yum install $DEPS_REDHAT -y
				else
					$SUDO yum install epel-release -y
					$SUDO yum install $DEPS_REDHAT -y
				fi

				if [[ $PLATFORM_DISTRIBUTION == "CentOS" && $PLATFORM_VERSION -eq 6 || $PLATFORM_DISTRIBUTION == "RHEL" && $PLATFORM_VERSION -eq 6 ]]; then
					for p in "${!BINARY_PATHS_ARRAY[@]}" ; do
						if [ -f "${BINARY_PATHS_ARRAY[$p]}/pngcrush" ]; then
							ISSET_pngcrush=1
						fi
					done
					if [ $ISSET_pngcrush -eq 0 ]; then
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
						if [ -f "${BINARY_PATHS_ARRAY[$p]}/advpng" ]; then
							ISSET_advpng=1
						fi
					done
					if [ $ISSET_advpng -eq 0 ]; then
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
	#			if [ -f "${BINARY_PATHS_ARRAY[$p]}/djpeg" ]; then
	#				ISSET_djpeg=1
	#			fi
	#		done
	#		for p in "${!BINARY_PATHS_ARRAY[@]}" ; do
	#			if [ -f "${BINARY_PATHS_ARRAY[$p]}/cjpeg" ]; then
	#				ISSET_cjpeg=1
	#			fi
	#		done

	#		if [[ $ISSET_djpeg -eq 0 || $ISSET_cjpeg -eq 0 ]]; then
	#			git clone https://github.com/mozilla/mozjpeg.git
	#			cd mozjpeg/
	#			autoreconf -fiv
	#			./configure
	#			if [ $PLATFORM_PKG == "debian" ]; then
	#				make deb
	#				$SUDO dpkg -i mozjpeg_*.deb
	#			else
	#				make
	#				$SUDO make install
	#			fi
	#			cd ../
	#			rm -rf mozjpeg
	#		fi

			if [ $ISSET_pngout -eq 0 ]; then
				wget http://static.jonof.id.au/dl/kenutils/pngout-20150319-linux.tar.gz
				tar -xf pngout-20150319-linux.tar.gz
				rm pngout-20150319-linux.tar.gz
				if [ $PLATFORM_ARCH == 64 ]; then
					$SUDO cp pngout-20150319-linux/x86_64/pngout /bin/pngout
				else
					$SUDO cp pngout-20150319-linux/i686/pngout /bin/pngout
				fi
				rm -rf pngout-20150319-linux
			fi

		elif [ $PLATFORM == "macos" ]; then

			# check /usr/local/Homebrew

			for p in "${!BINARY_PATHS_ARRAY[@]}" ; do
				if [ -f "${BINARY_PATHS_ARRAY[$p]}/brew" ]; then
					ISSET_brew=1
				else
					ISSET_brew=0
				fi
			done
			if [ $ISSET_brew -eq 0 ]; then
				/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
			fi

			brew install $DEPS_MACOS

		elif [ $PLATFORM == "freebsd" ]; then

#			for p in "${!BINARY_PATHS_ARRAY[@]}" ; do
#				if [ -f "${BINARY_PATHS_ARRAY[$p]}/git" ]; then
#					ISSET_git=1
#				else
#					ISSET_git=0
#				fi
#			done
#			if [[ $ISSET_git -eq 0 ]]; then
#				cd /usr/ports/devel/git/
#				make BATCH=yes install clean
#			fi

			for p in "${!BINARY_PATHS_ARRAY[@]}" ; do
				if [ -f "${BINARY_PATHS_ARRAY[$p]}/wget" ]; then
					ISSET_wget=1
				else
					ISSET_wget=0
				fi
			done
			if [ $ISSET_wget -eq 0 ]; then
				cd /usr/ports/ftp/wget/
				make BATCH=yes install clean
			fi

			if [ $ISSET_jpegoptim -eq 0 ]; then
				cd /usr/ports/graphics/jpegoptim/
				make BATCH=yes install clean
			fi

			if [[ $ISSET_djpeg -eq 0 || $ISSET_cjpeg -eq 0 || $ISSET_jpegtran -eq 0 ]]; then
				cd /usr/ports/graphics/jpeg/
				make BATCH=yes install clean
			fi

			if [ $ISSET_pngcrush -eq 0 ]; then
				cd /usr/ports/graphics/pngcrush/
				make BATCH=yes install clean
			fi

			if [ $ISSET_optipng -eq 0 ]; then
				cd /usr/ports/graphics/optipng/
				make BATCH=yes install clean
			fi

			if [ $ISSET_advpng -eq 0 ]; then
				cd /usr/ports/archivers/advancecomp/
				make BATCH=yes install clean
			fi

			if [ $ISSET_gifsicle -eq 0 ]; then
				cd /usr/ports/graphics/gifsicle/
				make BATCH=yes install clean
			fi

			if [ $ISSET_pngout -eq 0 ]; then
				cd ~
				wget http://static.jonof.id.au/dl/kenutils/pngout-20150319-bsd.tar.gz
				tar -xf pngout-20150319-bsd.tar.gz
				rm pngout-20150319-bsd.tar.gz
				if [ $PLATFORM_ARCH == 64 ]; then
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

getTimeMarkerPath()
{
	TIME_MARKER_PATH=$(echo "$TIME_MARKER_PATH" | sed 's/\/$//')
	if [ -z $TIME_MARKER ]; then
		if [ -z $TIME_MARKER_PATH ]; then
			echo "$DIR_PATH/$TIME_MARKER_NAME"
		else
			echo "$TIME_MARKER_PATH/$TIME_MARKER_NAME"
		fi
	else
		if [[ $TIME_MARKER == *\/* ]]; then
			echo "$TIME_MARKER"
		else
			if [ -z $TIME_MARKER_PATH ]; then
				echo "$DIR_PATH/$TIME_MARKER"
			else
				echo "$TIME_MARKER_PATH/$TIME_MARKER"
			fi
		fi
	fi
}

checkUserTimeMarker()
{
	if [[ $TIME_MARKER =~ ^-?.*\/$ ]]; then
		echo "Time marker filename not set in given path. Exiting..." 1>&2
		exit 1
	fi
}

checkTimeMarkerPermissions()
{
	if [[ "$OSTYPE" == "darwin"* ]]; then
		TIME_MARKER_MODIFIED=$(stat -t %s -f %m -- "$1")
	else
		TIME_MARKER_MODIFIED=$(date -r "$1" +%s)
	fi

	touch -m "$1" 2>/dev/null

	if [[ "$OSTYPE" == "darwin"* ]]; then
		TIME_MARKER_MODIFIED_NEW=$(stat -t %s -f %m -- "$1")
	else
		TIME_MARKER_MODIFIED_NEW=$(date -r "$1" +%s)
	fi

	if [ $TIME_MARKER_MODIFIED -eq $TIME_MARKER_MODIFIED_NEW ]; then
		echo "Current user have no permissions to modify time marker. Exiting..." 1>&2
		exit 1
	else
		if date --version >/dev/null 2>/dev/null ; then
			touch -t $(date '+%Y%m%d%H%M.%S' -d @$TIME_MARKER_MODIFIED) "$1" > /dev/null # GNU version of date
		else
			touch -t $(date -r $TIME_MARKER_MODIFIED +%Y%m%d%H%M.%S) "$1" > /dev/null # Non GNU version of date
		fi
	fi
}

updateTimeMarker()
{
	if [ $NEW_ONLY -eq 1 ]; then
		sleep 1
		touch -m "$TIME_MARKER_FULL_PATH" > /dev/null
		echo
		if [ $TIME_MARKER_ISSET -eq 1 ]; then
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
	djpeg -outfile "$TMP_PATH/$(basename "$1")" "$1" > /dev/null
	cjpeg -optimize -progressive -outfile "$1" "$TMP_PATH/$(basename "$1")" > /dev/null
	rm "$TMP_PATH/$(basename "$1")"
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
	if ! [ -z $OPTIPNG_V ]; then
		if [ $OPTIPNG_V -ge 7 ]; then
			optipng -strip all -o7 -q "$1" > /dev/null
		else
			optipng -o7 -q "$1" > /dev/null
		fi
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
	if [ $1 -ge 1000000000 ]; then
		echo -n $(echo "scale=1; $1/1024/1024/1024" | bc | sed 's/^\./0./')"Gb"
	elif [ $1 -ge 1000000 ]; then
		echo -n $(echo "scale=1; $1/1024/1024" | bc | sed 's/^\./0./')"Mb"
	else
		echo -n $(echo "scale=1; $1/1024" | bc | sed 's/^\./0./')"Kb"
	fi
}
readableTime()
{
	local T=$1
	local D=$((T/60/60/24))
	local H=$((T/60/60%24))
	local M=$((T/60%60))
	local S=$((T%60))
	(( $D > 0 )) && printf '%d days ' $D
	(( $H > 0 )) && printf '%d hours ' $H
	(( $M > 0 )) && printf '%d minutes ' $M
	(( $D > 0 || $H > 0 || $M > 0 )) && printf 'and '
	printf '%d seconds\n' $S
}

findExclude()
{
	if ! [ -z "$EXCLUDE_LIST" ]; then
		EXCLUDE_LIST=$(echo $EXCLUDE_LIST | sed 's/,$//g' | sed 's/^,//g' | sed 's/,/\\|/g')
		grep -v "$EXCLUDE_LIST"
	else
		grep -v ">>>>>>>>>>>>>"
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
	echo "    -h, --help              Shows this help."
	echo
	echo "    -v, --version           Shows script version."
	echo
	echo "    -p <dir>,               Specify full path to input directory with "
	echo "    --path=<dir>            or without slash in the end of path."
	echo
	echo "    -q, --quiet             Execute script without any questions and users "
	echo "                            actions."
	echo
	echo "    -l, --less              Don't show optimizing process."
	echo
	echo "    -c, --check-only        Check tools with an opportunity to install "
	echo "                            dependences. All options will be ignored "
	echo "                            with this option (except for -h|--help and "
	echo "                            -v|--version)."
	echo
	echo "    -t <period>,            Period for which to look for files by last "
	echo "    --time=<period>         modified time. Must be set in minutes (10m, 30m "
	echo "                            etc.) or hours (1h, 10h etc.) or days (1d, 30d "
	echo "                            etc.). It is impossible to use this option with "
	echo "                            -n|--new-only option. (test)"
	echo
	echo "    -n, --new-only          Looking for images newer than special time "
	echo "                            marker file. It is automatically created or "
	echo "                            modified in the end of optimizing using this "
	echo "                            option. Recommended for cron usage to avoid "
	echo "                            repeated optimization already optimized files. "
	echo "                            By default time marker creates in working "
	echo "                            directory which set in -p|--path option. It is "
	echo "                            impossible to use this option with -t|--time "
	echo "                            option. (test)"
	echo
	echo "    -m <name>,              Custom full path or name of time marker file. "
	echo "    --time-marker=<name>,   Must be name of file (for changes time marker "
	echo "    -m <path>,              name) or full path for custom time marker file "
	echo "    --time-marker=<path>    in custom directory. Working only with "
	echo "                            -n|--new-only option. (test)"
	echo
	echo "    -tmp <dir>,             Custom directory path for temporary files. "
	echo "    --tmp-path=<dir>        Default value located in TMP_PATH variable "
	echo "                            (/tmp by default)"
	echo
	echo "    -e <list>,              Comma separated parts list of paths to files "
	echo "    --exclude=<list>        for exclusion from search. The script removes "
	echo "                            from the search files in the full path of which "
	echo "                            includes any value from the list."
	echo
}

# Define inner default vars. Don't change them!
DEBUG=0
HELP=0
SHOW_VERSION=0
NO_ASK=0
LESS=0
CHECK_ONLY=0
PERIOD=0
NEW_ONLY=0
TIME_MARKER=""
EXCLUDE_LIST=""
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

	elif [ "${1#--tmp-path=}" != "$1" ] ; then
		TMP_PATH="${1#--tmp-path=}"
	elif [ "$1" = "-tmp" ] ; then
		shift ; TMP_PATH="$1"

	elif [ "${1#--exclude=}" != "$1" ] ; then
		EXCLUDE_LIST="${1#--exclude=}"
	elif [ "$1" = "-e" ] ; then
		shift ; EXCLUDE_LIST="$1"

	elif [[ "$1" = "--help" || "$1" = "-h" ]] ; then
		HELP=1

	elif [[ "$1" = "--version" || "$1" = "-v" ]] ; then
		SHOW_VERSION=1

	elif [[ "$1" = "--quiet" || "$1" = "-q" ]] ; then
		NO_ASK=1

	elif [[ "$1" = "--less" || "$1" = "-l" ]] ; then
		LESS=1

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

if [[ $HELP -eq 1 || $PARAMS_NUM -eq 0 ]]; then
	usage
	exit 0
fi

if [ $SHOW_VERSION -eq 1 ]; then
	CUR_VERSION=$(grep 'Version:\ ' $0 | cut -d ' ' -f3)
	echo $CUR_VERSION
	exit 0
fi

if [ $CHECK_ONLY -eq 0 ]; then

	DIR_PATH=$(echo "$DIR_PATH" | sed 's/\/$//')
	checkParm "$DIR_PATH" "Path to files not set. Exiting..."
	checkDir "$DIR_PATH"
	cdAndCheck "$DIR_PATH"
	checkDirPermissions "$DIR_PATH"

	TMP_PATH=$(echo "$TMP_PATH" | sed 's/\/$//')
	checkDir "$TMP_PATH" "Directory for temporary files not found. Exiting..."
	cdAndCheck "$TMP_PATH" "Can't get up in a directory for temporary files. Exiting..."
	checkDirPermissions "$TMP_PATH" "Current user have no permissions to directory for temporary files. Exiting..."

	if [[ $PERIOD != 0 && $NEW_ONLY -gt 0 ]]; then
		echo "It is impossible to use options -t(--time) and -n(--new-only) together. Set only one of it. Exiting..."
		exit 1
	fi

	if ! [ -z "$TIME_MARKER" ]; then
		if [ $NEW_ONLY -eq 0 ]; then
			echo "You can't use option -m(--time-marker) without -n(--new-only) option. Exiting..."
			exit 1
		fi
	fi

	if [ $PERIOD != 0 ]; then

		if ! [[ $PERIOD =~ ^-?[0-9]+(m|h|d)$ ]]; then
			echo "Wrong format of period. Exiting..."
			exit 1
		fi

		PERIOD_VAL=$(echo "$PERIOD" | sed 's/.$//')
		if [ $(echo "$PERIOD" | sed 's/[^mhd]*//') == "m" ]; then
			PERIOD_UNIT="m"
			PERIOD_UNIT_NAME="minute(s)"
			FIND_INCLUDE="-mmin -$PERIOD_VAL"
		elif [ $(echo "$PERIOD" | sed 's/[^mhd]*//') == "h" ]; then
			PERIOD_UNIT="h"
			PERIOD_UNIT_NAME="hour(s)"
			let PERIOD_VAL_H=$PERIOD_VAL*60
			FIND_INCLUDE="-mmin -$PERIOD_VAL_H"
		elif [ $(echo "$PERIOD" | sed 's/[^mhd]*//') == "d" ]; then
			PERIOD_UNIT="d"
			PERIOD_UNIT_NAME="day(s)"
			FIND_INCLUDE="-mtime -$PERIOD_VAL"
		fi
		echo
		echo "Script will be searching images changed for the last $PERIOD_VAL $PERIOD_UNIT_NAME."

	elif [ $NEW_ONLY -eq 1 ]; then

		echo
		echo "Script will be searching images newer than time marker."
		TIME_MARKER_FULL_PATH=$(getTimeMarkerPath)
		TIME_MARKER_FULL_PATH_DIR=$(dirname "$TIME_MARKER_FULL_PATH")
		TIME_MARKER_FULL_PATH_NAME=$(basename "$TIME_MARKER_FULL_PATH")
		checkDir "$TIME_MARKER_FULL_PATH_DIR" "Directory for time marker not found. Exiting..."
		cdAndCheck "$TIME_MARKER_FULL_PATH_DIR" "Can't get up in a directory for time marker. Exiting..."
		checkUserTimeMarker
		checkDirPermissions "$TIME_MARKER_FULL_PATH_DIR" "Current user have no permissions to directory for time marker. Exiting..."
		echo -n "Time marker "
		if [ -f "$TIME_MARKER_FULL_PATH" ]; then
			checkTimeMarkerPermissions "$TIME_MARKER_FULL_PATH"
			$SETCOLOR_SUCCESS
			echo -n "found"
			$SETCOLOR_NORMAL
			echo -n "."
			FIND_INCLUDE="-newer $TIME_MARKER_FULL_PATH"
			TIME_MARKER_ISSET=1
		else
			$SETCOLOR_FAILURE
			echo -n "not found"
			$SETCOLOR_NORMAL
			echo -n ". It will be created after optimizing."
			FIND_INCLUDE=""
			TIME_MARKER_ISSET=0
		fi
		if [ $DEBUG -eq 1 ]; then
			echo
			echo -n "($TIME_MARKER_FULL_PATH)"
		fi
		echo

	else

		FIND_INCLUDE=""

	fi

fi

BINARY_PATHS=$(echo $BINARY_PATHS | sed 's/\/\ /\ /g' | sed 's/\/$/\ /')
BINARY_PATHS_ARRAY=($BINARY_PATHS)
TOOLS_ARRAY=($TOOLS)
ALL_FOUND=1

echo
echo -n "Checking tools"
if [ $DEBUG -eq 1 ]; then
	echo -n " in $BINARY_PATHS"
fi
echo "..."

for t in "${!TOOLS_ARRAY[@]}" ; do

	FOUND=0
	echo -n ${TOOLS_ARRAY[$t]}"..."
	for p in "${!BINARY_PATHS_ARRAY[@]}" ; do
		if [ -f "${BINARY_PATHS_ARRAY[$p]}/${TOOLS_ARRAY[$t]}" ]; then
			FOUND=1
			TOOL_PATH="${BINARY_PATHS_ARRAY[$p]}/${TOOLS_ARRAY[$t]}"
		fi
	done
	if [ $FOUND -eq 1 ]; then
		$SETCOLOR_SUCCESS
		echo -n "[FOUND]"
		$SETCOLOR_NORMAL
		if [ $DEBUG -eq 1 ]; then
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

if [ $ALL_FOUND -eq 1 ]; then
	echo "All tools found"
	echo
	if [[ $NO_ASK -eq 0 && $CHECK_ONLY -eq 0 ]]; then
		sayWait
	fi
	if [ $CHECK_ONLY -eq 1 ]; then
		exit 0
	fi
else
	echo "One or more tools not found"
	echo
	if [ $NO_ASK -eq 0 ]; then
		echo "Please Select:"
		echo
		if [ $CHECK_ONLY -eq 0 ]; then
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
		if [ $CHECK_ONLY -eq 0 ]; then
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

IMAGES=$(\
find "$DIR_PATH" $FIND_INCLUDE \( \
-name '*.jpg' -or \
-name '*.jpeg' -or \
-name '*.gif' -or \
-name '*.JPG' -or \
-name '*.JPEG' -or \
-name '*.GIF' -or \
-name '*.png' -or \
-name '*.PNG' \
\) | findExclude)

IMAGES_TOTAL=$(\
find "$DIR_PATH" $FIND_INCLUDE \( \
-name '*.jpg' -or \
-name '*.jpeg' -or \
-name '*.gif' -or \
-name '*.JPG' -or \
-name '*.JPEG' -or \
-name '*.GIF' -or \
-name '*.png' -or \
-name '*.PNG' \
\) | findExclude | wc -l)

IMAGES_OPTIMIZED=0
IMAGES_CURRENT=0
START_TIME=$(date +%s)

if ! [ -z "$IMAGES" ]; then

	echo "Optimizing..."

	INPUT=0
	OUTPUT=0
	SAVED_SIZE=0

	echo "$IMAGES" | ( while read IMAGE ; do

		if [ $LESS -eq 0 ]; then
#			if [ $SHOW_PROGRESS -eq 1 ]; then
#				if [ $PROGRESS_MEASURE == "percent" ]; then
#					IMAGES_CURRENT_PERCENT=$(echo "scale=2; $IMAGES_CURRENT*100/$IMAGES_TOTAL" | bc)
#					IMAGES_CURRENT=$(echo "$IMAGES_CURRENT+1" | bc)
#					echo -n "[$IMAGES_CURRENT_PERCENT%] "
#				fi
#				if [ $PROGRESS_MEASURE == "num" ]; then
					IMAGES_CURRENT=$(echo "$IMAGES_CURRENT+1" | bc)
					echo -n "["
					echo -n $IMAGES_CURRENT
					echo -n "/"
					echo -n $IMAGES_TOTAL
					echo -n "] "
#				fi
#			fi
			echo -n "$IMAGE"
			echo -n '... '
		fi
		SIZE_BEFORE=$(wc -c "$IMAGE" | awk '{print $1}')
		SIZE_BEFORE_SCALED=$(echo "scale=1; $SIZE_BEFORE/1024" | bc | sed 's/^\./0./')
		INPUT=$(echo "$INPUT+$SIZE_BEFORE" | bc)

		EXT=${IMAGE##*.}

		if [[ $EXT == "jpg" || $EXT == "jpeg" || $EXT == "JPG" || $EXT == "JPEG" ]]; then

			if [ $ISSET_jpegoptim -eq 1 ]; then
				optimJpegoptim "$IMAGE"
			fi

			if [ $ISSET_jpegtran -eq 1 ]; then
				optimJpegtran "$IMAGE"
			fi

			if [[ $ISSET_djpeg -eq 1 && $ISSET_cjpeg -eq 1 ]]; then
				optimMozjpeg "$IMAGE"
			fi

		elif [[ $EXT == "png" || $EXT == "PNG" ]]; then

	#		if [ $ISSET_convert -eq 1 ]; then
	#			optimConvert "$IMAGE"
	#		fi

			if [[ "$OSTYPE" == "linux-gnu" ]]; then
				CUR_OWNER=$(stat -c "%U:%G" "$IMAGE")
				CUR_PERMS=$(stat -c "%a" "$IMAGE")
			else
				#CUR_OWNER=$(stat -f "%Su" "$IMAGE")
				CUR_OWNER=$(ls -l "$IMAGE" | awk '{print $3":"$4}')
				CUR_PERMS=$(stat -f "%Lp" "$IMAGE")
			fi

			if [ $ISSET_pngcrush -eq 1 ]; then
				optimPngcrush "$IMAGE"
			fi

			if [ $ISSET_optipng -eq 1 ]; then
				optimOptipng "$IMAGE"
			fi

			if [ $ISSET_pngout -eq 1 ]; then
				optimPngout "$IMAGE"
			fi

			if [ $ISSET_advpng -eq 1 ]; then
				optimAdvpng "$IMAGE"
			fi

			chown $CUR_OWNER "$IMAGE"
			chmod $CUR_PERMS "$IMAGE"

		elif [[ $EXT == "gif" || $EXT == "GIF" ]]; then

			if [ $ISSET_gifsicle -eq 1 ]; then
				optimGifsicle "$IMAGE"
			fi

		fi

		SIZE_AFTER=$(wc -c "$IMAGE" | awk '{print $1}')
		SIZE_AFTER_SCALED=$(echo "scale=1; $SIZE_AFTER/1024" | bc | sed 's/^\./0./')
		OUTPUT=$(echo "$OUTPUT+$SIZE_AFTER" | bc)
		if [ $(echo "scale=0; $SIZE_BEFORE/100" | bc) -le $(echo "scale=0; $SIZE_AFTER/100" | bc) ]; then
			if [ $LESS -eq 0 ]; then
				$SETCOLOR_FAILURE
				echo -n "[NOT OPTIMIZED]"
				$SETCOLOR_NORMAL
				echo -n " ${SIZE_AFTER_SCALED}Kb"
			fi
		else
			if [ $LESS -eq 0 ]; then
				$SETCOLOR_SUCCESS
				echo -n "[OPTIMIZED]"
				$SETCOLOR_NORMAL
				echo -n " ${SIZE_BEFORE_SCALED}Kb -> ${SIZE_AFTER_SCALED}Kb"
			fi
			SIZE_DIFF=$(echo "$SIZE_BEFORE-$SIZE_AFTER" | bc)
			SAVED_SIZE=$(echo "$SAVED_SIZE+$SIZE_DIFF" | bc)
			IMAGES_OPTIMIZED=$(echo "$IMAGES_OPTIMIZED+1" | bc)
		fi

		if [ $LESS -eq 0 ]; then
			echo
		fi

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
	
	echo -n "Optimized/Total: "
	echo -n $IMAGES_OPTIMIZED
	echo -n " / "
	echo -n $IMAGES_TOTAL
	echo " files"
	END_TIME=$(date +%s)
	TOTAL_TIME=$(echo "$END_TIME-$START_TIME" | bc)
	echo -n "Total optimizing time: "
	readableTime $TOTAL_TIME
	)
	updateTimeMarker

else

	echo "No input images found."

fi

echo
exit 0
