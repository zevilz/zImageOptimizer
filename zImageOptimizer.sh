#!/bin/bash
# Simple image optimizer for JPEG, PNG and GIF images.
# URL: https://github.com/zevilz/zImageOptimizer
# Author: Alexandr "zEvilz" Emshanov
# License: MIT
# Version: 0.1.0

BINARY_PATHS="/bin/ /usr/bin/ /usr/local/bin/"
TMP_PATH="/tmp/"
TOOLS="jpegoptim jpegtran djpeg cjpeg pngcrush optipng pngout advpng"
DEPS="jpegoptim libjpeg-turbo-progs pngcrush optipng advancecomp autoconf automake libtool nasm make pkg-config git"
GIT_URL="https://github.com/zevilz/zImageOptimizer"

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
		echo "Can't get up in a directory $1 or an excess slash in the end of path. Exiting..." 1>&2
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
	touch test 2>/dev/null
	if ! [ -f "$1/test" ] ; then
		echo "Current user have no permissions to directory $1. Exiting..." 1>&2
		exit 1
	else
		rm "$1/test"
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
	if [[ "$OSTYPE" == "linux-gnu" ]]; then
		PLATFORM="linux"
		PLATFORM_PKG="unknown"

		# First test against Fedora / RHEL / CentOS / generic Redhat derivative
		if [ -r /etc/rc.d/init.d/functions ]; then
			source /etc/rc.d/init.d/functions
			[ zz`type -t passed 2>/dev/null` == "zzfunction" ] && PLATFORM_PKG="redhat"

		# Then test against SUSE (must be after Redhat,
		# I've seen rc.status on Ubuntu I think? TODO: Recheck that)
		elif [ -r /etc/rc.status ]; then
			source /etc/rc.status
			[ zz`type -t rc_reset 2>/dev/null` == "zzfunction" ] && PLATFORM_PKG="suse"

		# Then test against Debian, Ubuntu and friends
		elif [ -r /lib/lsb/init-functions ]; then
			source /lib/lsb/init-functions
			[ zz`type -t log_begin_msg 2>/dev/null` == "zzfunction" ] && PLATFORM_PKG="debian"

		# Then test against Gentoo
		elif [ -r /etc/init.d/functions.sh ]; then
			source /etc/init.d/functions.sh
			[ zz`type -t ebegin 2>/dev/null` == "zzfunction" ] && PLATFORM_PKG="gentoo"

		# For Slackware we currently just test if /etc/slackware-version exists
		# and isn't empty (TODO: Find a better way :)
		elif [ -s /etc/slackware-version ]; then
			PLATFORM_PKG="slackware"
		fi

#	elif [[ "$OSTYPE" == "darwin"* ]]; then
#		PLATFORM="macos"
#	elif [[ "$OSTYPE" == "freebsd"* ]]; then
#		PLATFORM="freebsd"
	else
		PLATFORM="unknown"
	fi
	
	if ! [ $PLATFORM == "unknown" ]
	then
		if ! [ $PLATFORM_PKG == "unknown" ]
		then
			echo "Installing dependences..."
			whoami > /dev/null
			if [ $? == "root" ]
			then
				SUDO=""
			else
				SUDO="sudo"
			fi
			if [ $PLATFORM_PKG == "debian" ]
			then
				$SUDO apt-get update
				$SUDO apt-get install $DEPS -y
			fi
			if [[ $ISSET_djpeg == 0 || $ISSET_cjpeg == 0 ]]
			then
				git clone https://github.com/mozilla/mozjpeg.git
				cd mozjpeg/
				autoreconf -fiv
				./configure
				if [ $PLATFORM_PKG == "debian" ]
				then
					make deb
					$SUDO dpkg -i mozjpeg_*.deb
				fi
				cd ../
				rm -rf mozjpeg
			fi
			if [[ $ISSET_pngout == 0 ]]
			then
				wget http://static.jonof.id.au/dl/kenutils/pngout-20150319-linux.tar.gz
				tar -xf pngout-20150319-linux.tar.gz
				rm pngout-20150319-linux.tar.gz
				cp pngout-20150319-linux/x86_64/pngout /bin/pngout
				rm -rf pngout-20150319-linux
			fi
		else
			echo "Your package manager not supported! Please install dependaces manually."
			echo "Info: $GIT_URL"
			echo
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
	echo "Script to optimize JPG and PNG images in a directory."
	echo
	echo "Options:"
	echo "	-h, --help         shows this help"
	echo "	-p, --path [dir]   specify input directory"
	echo
}

HELP=0
PARAMS_NUM=$#

while [ 1 ] ; do
	if [ "${1#--path=}" != "$1" ] ; then
		path="${1#--path=}"
	elif [ "$1" = "-p" ] ; then
		shift ; path="$1"

	elif [ "${1#--help}" != "$1" ] ; then
		HELP=1
	elif [ "$1" = "-h" ] ; then
		shift ; HELP=1

	elif [ -z "$1" ] ; then
		break
	else
		echo "Ошибка: неизвестный ключ" 1>&2
		exit 1
	fi
	shift
done

if [[ $HELP == 1 || $PARAMS_NUM == 0 ]]
then
	usage
	exit 1
fi

checkParm "$path" "Path to files not set (-p|--path)"
checkDir "$path"
cdAndCheck "$path"
checkDirPermissions "$path"

BINARY_PATHS_ARRAY=($BINARY_PATHS)
TOOLS_ARRAY=($TOOLS)
ALL_FOUND=1

echo
echo "Checking tools..."

for t in "${!TOOLS_ARRAY[@]}" ; do
	FOUND=0
	echo -n ${TOOLS_ARRAY[$t]}"..."
	for p in "${!BINARY_PATHS_ARRAY[@]}" ; do
		if [ -f "${BINARY_PATHS_ARRAY[$p]}${TOOLS_ARRAY[$t]}" ]
		then
			FOUND=1
		fi
	done
	if [ $FOUND == 1 ]
	then
		$SETCOLOR_SUCCESS
		echo "[FOUND]"
		$SETCOLOR_NORMAL
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
	sayWait
else
	echo "One or more tools not found"
	echo
	echo "Please Select:"
	echo
	echo "1. Continue (default)"
	echo "2. Install dependences and exit"
	echo "0. Exit"
	echo
	echo -n "Enter selection [1] > "
	read item
	case "$item" in
		1) echo
			;;
		0) echo "Exiting..."
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
fi

echo "Optimizing..."

INPUT=0
OUTPUT=0
SAVED_SIZE=0

#find $path \( -name '*.jpg' -or -name '*.jpeg' -or -name '*.gif' -or -name '*.JPG' -or -name '*.JPEG' -or -name '*.GIF' -or -name '*.png' -or -name '*.PNG' \) | ( while read IMAGE ; do
find $path \( -name '*.jpg' -or -name '*.jpeg' -or -name '*.JPG' -or -name '*.JPEG' -or -name '*.png' -or -name '*.PNG' \) | ( while read IMAGE ; do
	echo -n "$IMAGE"
	echo -n '...'
	SIZE_BEFORE=$(stat "$IMAGE" -c %s)
	SIZE_BEFORE_SCALED=$(echo "scale=1; $SIZE_BEFORE/1024" | bc | sed 's/^\./0./')
	INPUT=$(echo "$INPUT+$SIZE_BEFORE" | bc)

	EXT=${IMAGE##*.}

	if [[ $EXT == "jpg" || $EXT == "jpeg" || $EXT == "JPG" || $EXT == "JPEG" ]]
	then
		echo -n " "

		if [ $ISSET_jpegoptim == 1 ]
		then
			jpegoptim --strip-all "$IMAGE" > /dev/null
		fi

		if [ $ISSET_jpegtran == 1 ]
		then
			jpegtran -progressive -copy none -optimize "$IMAGE" > /dev/null
		fi

		if [[ $ISSET_djpeg == 1 && $ISSET_cjpeg == 1 ]]
		then
			djpeg -outfile $TMP_PATH"$(basename "$IMAGE")" "$IMAGE" > /dev/null
			cjpeg -optimize -progressive -outfile "$IMAGE" $TMP_PATH"$(basename "$IMAGE")" > /dev/null
			rm $TMP_PATH"$(basename "$IMAGE")"
		fi
	elif [[ $EXT == "png" || $EXT == "PNG" ]]
	then
		echo -n " "

		if [ $ISSET_pngcrush == 1 ]
		then
			pngcrush -rem gAMA -rem cHRM -rem iCCP -rem sRGB -brute -l 9 -reduce -q -ow "$IMAGE" > /dev/null
		fi

		if [ $ISSET_optipng == 1 ]
		then
			optipng -strip all -o7 -q "$IMAGE" > /dev/null
		fi

		if [ $ISSET_pngout == 1 ]
		then
			pngout -q -y -k0 -s0 "$IMAGE" > /dev/null
		fi

		if [ $ISSET_advpng == 1 ]
		then
			advpng -z -4 "$IMAGE" > /dev/null
		fi
#	elif [[ $EXT == "gif" || $EXT == "GIF" ]]
#	then
#		# gif tools
	fi

	SIZE_AFTER=$(stat "$IMAGE" -c %s)
	SIZE_AFTER_SCALED=$(echo "scale=1; $SIZE_AFTER/1024" | bc | sed 's/^\./0./')
	OUTPUT=$(echo "$OUTPUT+$SIZE_AFTER" | bc)
	if [ $(echo "scale=0; $SIZE_BEFORE/100" | bc) -le $(echo "scale=0; $SIZE_AFTER/100" | bc) ]
	then
		$SETCOLOR_FAILURE
		echo -n "[NOT OPTIMIZED]"
		$SETCOLOR_NORMAL
		echo -n " ${SIZE_AFTER_SCALED}kb"
	else
		$SETCOLOR_SUCCESS
		echo -n "[OPTIMIZED]"
		$SETCOLOR_NORMAL
		echo -n " ${SIZE_BEFORE_SCALED}k -> ${SIZE_AFTER_SCALED}kb"
		SIZE_DIFF=$(echo "$SIZE_BEFORE-$SIZE_AFTER" | bc)
		SAVED_SIZE=$(echo "$SAVED_SIZE+$SIZE_DIFF" | bc)
	fi
	echo
done

echo
echo -n "Input: "
if [ $INPUT -ge 1000000000 ]
then
	echo $(echo "scale=1; $INPUT/1024/1024/1024" | bc | sed 's/^\./0./')"Gb"
elif [ $INPUT -ge 1000000 ]
then
	echo $(echo "scale=1; $INPUT/1024/1024" | bc | sed 's/^\./0./')"Mb"
else
	echo $(echo "scale=1; $INPUT/1024" | bc | sed 's/^\./0./')"kb"
fi

echo -n "Output: "
if [ $OUTPUT -ge 1000000000 ]
then
	echo $(echo "scale=1; $OUTPUT/1024/1024/1024" | bc | sed 's/^\./0./')"Gb"
elif [ $OUTPUT -ge 1000000 ]
then
	echo $(echo "scale=1; $OUTPUT/1024/1024" | bc | sed 's/^\./0./')"Mb"
else
	echo $(echo "scale=1; $OUTPUT/1024" | bc | sed 's/^\./0./')"kb"
fi

echo -n "You save: "
if [ $SAVED_SIZE -ge 1000000000 ]
then
	echo $(echo "scale=1; $SAVED_SIZE/1024/1024/1024" | bc | sed 's/^\./0./')"Gb"
elif [ $SAVED_SIZE -ge 1000000 ]
then
	echo $(echo "scale=1; $SAVED_SIZE/1024/1024" | bc | sed 's/^\./0./')"Mb"
else
	echo $(echo "scale=1; $SAVED_SIZE/1024" | bc | sed 's/^\./0./')"kb"
fi )

echo
