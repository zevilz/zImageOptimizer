#!/usr/bin/env bash
# Simple image optimizer for JPEG, PNG and GIF images.
# URL: https://github.com/zevilz/zImageOptimizer
# Author: Alexandr "zEvilz" Emshanov
# License: MIT
# Version: 0.10.4

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
		echo
		$SETCOLOR_FAILURE
		if [ -z "$2" ]; then
			echo "Can't get up in a directory $1!" 1>&2
		else
			echo "$2" 1>&2
		fi
		$SETCOLOR_NORMAL
		echo
		exit 1
	fi
}

checkDir()
{
	if ! [ -d "$1" ]; then
		echo
		$SETCOLOR_FAILURE
		if [ -z "$2" ]; then
			echo "Directory $1 not found!" 1>&2
		else
			echo "$2" 1>&2
		fi
		$SETCOLOR_NORMAL
		echo
		exit 1
	fi
}

checkDirPermissions()
{
	cd "$1" 2>/dev/null
	touch checkDirPermissions 2>/dev/null
	if ! [ -f "$1/checkDirPermissions" ]; then
		echo
		$SETCOLOR_FAILURE
		if [ -z "$2" ]; then
			echo "Current user have no permissions to directory $1!" 1>&2
		else
			echo "$2" 1>&2
		fi
		$SETCOLOR_NORMAL
		echo
		exit 1
	else
		rm "$1/checkDirPermissions"
	fi
}

checkParm()
{
	if [ -z "$1" ]; then
		echo
		$SETCOLOR_FAILURE
		echo "$2" 1>&2
		$SETCOLOR_NORMAL
		echo
		exit 1
	fi
}

inArray () {
	local e match="$1"
	shift
	for e; do [[ "$e" == "$match" ]] && return 0; done
	return 1
}

installDeps()
{
	PLATFORM="unknown"
	PLATFORM_ARCH="unknown"
	PLATFORM_SUPPORT=0
	if [[ "$OSTYPE" == "linux-gnu"* ]]; then
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
		if [[ $(echo $PLATFORM_VERSION | cut -d '.' -f1) -ge $MIN_VERSION_MACOS ]]; then
			PLATFORM_SUPPORT=1
		fi

	elif [[ "$OSTYPE" == "FreeBSD"* ]]; then

		PLATFORM="freebsd"
		PLATFORM_PKG="pkg"
		PLATFORM_DISTRIBUTION="FreeBSD"

		PLATFORM_ARCH=$(getconf LONG_BIT)

		PLATFORM_VERSION=$(freebsd-version | cut -d '-' -f1)
		if [[ $(echo $PLATFORM_VERSION | cut -d '.' -f1) -ge $MIN_VERSION_FREEBSD ]]; then
			PLATFORM_SUPPORT=1
		fi

	fi

	# Hook: after-check-platform
	includeExtensions after-check-platform

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
		echo "Installing dependencies..."

		CUR_USER=$(whoami)
		if [ $CUR_USER == "root" ]; then
			SUDO=""
		else
			SUDO="sudo"
		fi

		if [ $PLATFORM == "linux" ]; then

			# Hook: before-install-deps-linux
			includeExtensions before-install-deps-linux

			if [ $PLATFORM_PKG == "debian" ]; then

				# Hook: before-install-deps-debian
				includeExtensions before-install-deps-debian

				$SUDO apt-get update
				$SUDO apt-get install $DEPS_DEBIAN -y

				# Hook: after-install-deps-debian
				includeExtensions after-install-deps-debian

			elif [ $PLATFORM_PKG == "redhat" ]; then

				# Hook: before-install-deps-redhat
				includeExtensions before-install-deps-redhat

				if [ $PLATFORM_DISTRIBUTION == "Fedora" ]; then

					# Hook: before-install-deps-redhat-fedora
					includeExtensions before-install-deps-redhat-fedora

					$SUDO dnf install epel-release -y
					$SUDO dnf install $DEPS_REDHAT -y

					# Hook: after-install-deps-redhat-fedora
					includeExtensions after-install-deps-redhat-fedora

				elif [ $PLATFORM_DISTRIBUTION == "RHEL" ]; then

					# Hook: before-install-deps-redhat-rhel
					includeExtensions before-install-deps-redhat-rhel

					$SUDO yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$PLATFORM_VERSION.noarch.rpm -y
					echo
					echo -n "Enabling rhel-$PLATFORM_VERSION-server-optional-rpms repository..."
					$SUDO subscription-manager repos --enable rhel-$PLATFORM_VERSION-server-optional-rpms
					$SUDO yum install $DEPS_REDHAT -y

					# Hook: after-install-deps-redhat-rhel
					includeExtensions after-install-deps-redhat-rhel

				else

					# Hook: before-install-deps-redhat-other
					includeExtensions before-install-deps-redhat-other

					$SUDO yum install epel-release -y
					$SUDO yum install $DEPS_REDHAT -y

					# Hook: after-install-deps-redhat-other
					includeExtensions after-install-deps-redhat-other

				fi

				# Hook: after-install-deps-redhat
				includeExtensions after-install-deps-redhat

				if [[ $PLATFORM_DISTRIBUTION == "CentOS" && $PLATFORM_VERSION -eq 6 || $PLATFORM_DISTRIBUTION == "RHEL" && $PLATFORM_VERSION -eq 6 ]]; then
					for p in "${!BINARY_PATHS_ARRAY[@]}" ; do
						if [ -f "${BINARY_PATHS_ARRAY[$p]}/pngcrush" ]; then
							ISSET_pngcrush=1
						fi
					done
					if ! [ -z $ISSET_pngcrush ] && [ $ISSET_pngcrush -eq 0 ]; then
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
					if ! [ -z $ISSET_advpng ] && [ $ISSET_advpng -eq 0 ]; then
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

			if ! [ -z $ISSET_pngout ] && [ $ISSET_pngout -eq 0 ]; then
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

			# Hook: after-install-deps-linux
			includeExtensions after-install-deps-linux

		elif [ $PLATFORM == "macos" ]; then

			# Hook: before-install-deps-macos
			includeExtensions before-install-deps-macos

			checkHomebrew
			brew install $DEPS_MACOS

			# Hook: after-install-deps-macos
			includeExtensions after-install-deps-macos

		elif [ $PLATFORM == "freebsd" ]; then

			# Hook: before-install-deps-freebsd
			includeExtensions before-install-deps-freebsd

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

			if ! [ -z $ISSET_jpegoptim ] && [ $ISSET_jpegoptim -eq 0 ]; then
				cd /usr/ports/graphics/jpegoptim/
				make BATCH=yes install clean
			fi

			if ! [[ -z $ISSET_djpeg || -z $ISSET_cjpeg || -z $ISSET_jpegtran ]] && [[ $ISSET_djpeg -eq 0 || $ISSET_cjpeg -eq 0 || $ISSET_jpegtran -eq 0 ]]; then
				cd /usr/ports/graphics/jpeg/
				make BATCH=yes install clean
			fi

			if ! [ -z $ISSET_pngcrush ] && [ $ISSET_pngcrush -eq 0 ]; then
				cd /usr/ports/graphics/pngcrush/
				make BATCH=yes install clean
			fi

			if ! [ -z $ISSET_optipng ] && [ $ISSET_optipng -eq 0 ]; then
				cd /usr/ports/graphics/optipng/
				make BATCH=yes install clean
			fi

			if ! [ -z $ISSET_advpng ] && [ $ISSET_advpng -eq 0 ]; then
				cd /usr/ports/archivers/advancecomp/
				make BATCH=yes install clean
			fi

			if ! [ -z $ISSET_gifsicle ] && [ $ISSET_gifsicle -eq 0 ]; then
				cd /usr/ports/graphics/gifsicle/
				make BATCH=yes install clean
			fi

			if ! [ -z $ISSET_pngout ] && [ $ISSET_pngout -eq 0 ]; then
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

			# Hook: after-install-deps-freebsd
			includeExtensions after-install-deps-freebsd

		fi

	else
		echo "Your platform is not supported! Please install dependaces manually."
		echo "Info: $GIT_URL#manual-installing-dependences"
		echo
	fi
}

checkBashVersion()
{
	if [[ $(echo $BASH_VERSION | cut -d '.' -f1) -lt $BASH_MIN_VERSION ]]; then
		echo
		$SETCOLOR_FAILURE
		echo "Detected unsupported version of bash - ${BASH_VERSION}!"
		echo "${BASH_MIN_VERSION}.* required."
		$SETCOLOR_NORMAL
		if [[ "$OSTYPE" == "darwin"* ]]; then
			echo "1. Install new version and exit"
			echo "0. Exit (default)"
			echo
			echo -n "Enter selection [0] > "
			read item
			case "$item" in
				0) echo
					echo "Exiting..."
					echo
					exit 0
					;;
				1) echo
					installBashMacOS
					echo "Exiting..."
					echo
					exit 0
					;;
				*) echo
					echo "Exiting..."
					echo
					exit 0
					;;
			esac
		else
			echo
			exit 0
		fi
	fi
}

installBashMacOS()
{
	checkHomebrew
	brew install bash

	CUR_USER=$(whoami)
	if [ $CUR_USER == "root" ]; then
		SUDO=""
	else
		SUDO="sudo"
	fi

	if [ -z $(grep '/usr/local/bin/bash' /private/etc/shells) ]; then
		$SUDO bash -c "echo '/usr/local/bin/bash' >> /private/etc/shells"
	fi
	if [ -f '~/.bash_profile' ]; then
		if [ -z $(grep 'alias bash="/usr/local/bin/bash"' ~/.bash_profile) ]; then
			bash -c "echo 'alias bash=\"/usr/local/bin/bash\"' >> ~/.bash_profile"
		fi
	else
		bash -c "echo 'alias bash=\"/usr/local/bin/bash\"' > ~/.bash_profile"
	fi
	bash -c 'alias bash="/usr/local/bin/bash"'
}

checkHomebrew()
{
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
		echo
		$SETCOLOR_FAILURE
		echo "Time marker filename not set in given path!" 1>&2
		$SETCOLOR_NORMAL
		echo
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
		echo
		$SETCOLOR_FAILURE
		echo "Current user have no permissions to modify time marker!" 1>&2
		$SETCOLOR_NORMAL
		echo
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
		touch -m "$TIME_MARKER_FULL_PATH" > /dev/null
		if [ $TIME_MARKER_ISSET -eq 1 ]; then
			echo "Time marker updated."
		else
			echo "Time marker created."
		fi
		echo
	fi
}

fixTimeMarker()
{
	if [ $NEW_ONLY -eq 1 ]; then
		if [[ "$OSTYPE" == "darwin"* ]]; then
			TIME_MARKER_MODIFIED_TIME=$(stat -t %s -f %m -- "$TIME_MARKER_FULL_PATH")
		else
			TIME_MARKER_MODIFIED_TIME=$(date -r "$TIME_MARKER_FULL_PATH" +%s)
		fi

		TIME_MARKER_MODIFIED_TIME=$(echo "$TIME_MARKER_MODIFIED_TIME+1" | bc)

		if date --version >/dev/null 2>/dev/null ; then
			touch -t $(date '+%Y%m%d%H%M.%S' -d @$TIME_MARKER_MODIFIED_TIME) "$TIME_MARKER_FULL_PATH" > /dev/null # GNU version of date
		else
			touch -t $(date -r $TIME_MARKER_MODIFIED_TIME +%Y%m%d%H%M.%S) "$TIME_MARKER_FULL_PATH" > /dev/null # Non GNU version of date
		fi
	fi
}

updateModifyTime()
{
	if [ $NEW_ONLY -eq 1 ]; then
		touch "$IMAGE" -r "$TIME_MARKER_FULL_PATH" > /dev/null
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

optimXjpeg()
{
	# decompress in temp file
	djpeg -outfile "$TMP_PATH/$(basename "$1")" "$1" > /dev/null 2>/dev/null

	if [ -f "$TMP_PATH/$(basename "$1")" ]; then

		SIZE_CHECK=$(wc -c "$TMP_PATH/$(basename "$1")" | awk '{print $1}')

		if [[ SIZE_CHECK -gt 0 ]]; then

			# compress and replace original file if temp file exists and not empty
			cjpeg -quality 95 -optimize -progressive -outfile "$1" "$TMP_PATH/$(basename "$1")" > /dev/null

		fi

	fi

	# cleanup
	if [ -f "$TMP_PATH/$(basename "$1")" ]; then
		rm "$TMP_PATH/$(basename "$1")"
	fi
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

optimJPG()
{
	#if [[ $ISSET_djpeg -eq 1 && $ISSET_cjpeg -eq 1 ]]; then
	#	optimXjpeg "$1"
	#fi

	if [[ $ISSET_jpegoptim -eq 1 ]]; then
		optimJpegoptim "$1"
	fi

	if [[ $ISSET_jpegtran -eq 1 ]]; then
		optimJpegtran "$1"
	fi
}

optimPNG()
{
	if [[ $ISSET_pngcrush -eq 1 ]]; then
		optimPngcrush "$1"
	fi

	if [[ $ISSET_optipng -eq 1 ]]; then
		optimOptipng "$1"
	fi

	if [[ $ISSET_pngout -eq 1 ]]; then
		optimPngout "$1"
	fi

	if [[ $ISSET_advpng -eq 1 ]]; then
		optimAdvpng "$1"
	fi
}

optimGIF()
{
	if [[ $ISSET_gifsicle -eq 1 ]]; then
		optimGifsicle "$1"
	fi
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

checkEnabledExtensions()
{
	if ! [ -z "$ENABLED_EXTENSIONS" ]; then
		cd "$SCRIPT_PATH"
		if [ -d extensions ]; then
			if [[ "$ENABLED_EXTENSIONS" != "all" ]]; then
				if ! [[ "$ENABLED_EXTENSIONS" =~ ^[[:alnum:],_-]+$ ]]; then
					echo
					$SETCOLOR_FAILURE
					echo "Wrong format of extensions list!"
					$SETCOLOR_NORMAL
					echo
					exit 1
				else
					ENABLED_EXTENSIONS=$(echo $ENABLED_EXTENSIONS | sed 's/,$//g' | sed 's/^,//g' | sed 's/,/\ /g')
					ENABLED_EXTENSIONS_ARR=($ENABLED_EXTENSIONS)
					echo
					echo "Checking selected extensions..."
					for ENABLED_EXTENSION in ${ENABLED_EXTENSIONS_ARR[@]}; do
						echo -n "${ENABLED_EXTENSION}..."
						if ! [[ -z $(grep -lr "^#\ Extension:\ $ENABLED_EXTENSION$" extensions | tr '\n' ' ' | sed 's/\ $//') ]]; then
							$SETCOLOR_SUCCESS
							echo "[FOUND]"
							$SETCOLOR_NORMAL
						else
							$SETCOLOR_FAILURE
							echo "[NOT FOUND]"
							$SETCOLOR_NORMAL
						fi
					done
				fi
			else
				echo
				echo "Enabled all extensions."
			fi
		else
			echo
			$SETCOLOR_FAILURE
			echo "Extensions dir not found!"
			$SETCOLOR_NORMAL
			echo
			exit 1
		fi
	fi
}

includeExtensions()
{
	if ! [ -z "$ENABLED_EXTENSIONS" ]; then
		cd "$SCRIPT_PATH"
		if ! [ -z "$1" ] && [ -d extensions ]; then
			local EXTF_LIST=$(grep -lr "^#\ Hook:\ $1$" extensions | tr '\n' ' ' | sed 's/\ $//')
			if ! [ -z "$EXTF_LIST" ]; then
				local EXTF_ARR=("$EXTF_LIST")
				for EXTF in $EXTF_ARR; do
					if [[ "$ENABLED_EXTENSIONS" == "all" ]]; then
						. "$EXTF"
					else
						local EXTF_EXTENSION=$(grep -Eo '^#\ Extension:\ [[:alnum:]_-]+$' "$EXTF" | cut -d ' ' -f3)
						if inArray "$EXTF_EXTENSION" "${ENABLED_EXTENSIONS_ARR[@]}"; then
							. "$EXTF"
						fi
					fi
				done
			fi
		fi
	fi
}

joinBy()
{
	local d=$1
	shift
	echo -n "$1"
	shift
	printf "%s" "${@/#/$d}"
}

lockDir()
{
	if [ -f "${TMP_PATH}/${LOCK_FILE_NAME}" ]; then
		sed "/^$/d" "${TMP_PATH}/${LOCK_FILE_NAME}" > "${TMP_PATH}/${LOCK_FILE_NAME}.tmp" && \
		mv "${TMP_PATH}/${LOCK_FILE_NAME}.tmp" "${TMP_PATH}/${LOCK_FILE_NAME}"
		echo "$DIR_PATH" >> "${TMP_PATH}/${LOCK_FILE_NAME}"
	else
		echo "$DIR_PATH" > "${TMP_PATH}/${LOCK_FILE_NAME}"
	fi
}

unlockDir()
{
	if [ -f "${TMP_PATH}/${LOCK_FILE_NAME}" ]; then
		sed "/^$/d" "${TMP_PATH}/${LOCK_FILE_NAME}" > "${TMP_PATH}/${LOCK_FILE_NAME}.tmp" && \
		mv "${TMP_PATH}/${LOCK_FILE_NAME}.tmp" "${TMP_PATH}/${LOCK_FILE_NAME}"
		if [[ $(wc -l "${TMP_PATH}/${LOCK_FILE_NAME}" | sed 's/^[\ ]*//' | cut -d ' ' -f1) -gt 1 ]]; then
			grep -v "^${DIR_PATH}$" "${TMP_PATH}/${LOCK_FILE_NAME}" > "${TMP_PATH}/${LOCK_FILE_NAME}.tmp" && \
			mv "${TMP_PATH}/${LOCK_FILE_NAME}.tmp" "${TMP_PATH}/${LOCK_FILE_NAME}"
		else
			rm "${TMP_PATH}/${LOCK_FILE_NAME}"
		fi
	fi
}

checkDirLock()
{
	if [ -f "${TMP_PATH}/${LOCK_FILE_NAME}" ]; then
		sed "/^$/d" "${TMP_PATH}/${LOCK_FILE_NAME}" > "${TMP_PATH}/${LOCK_FILE_NAME}.tmp" && \
		mv "${TMP_PATH}/${LOCK_FILE_NAME}.tmp" "${TMP_PATH}/${LOCK_FILE_NAME}"
		if [[ $(grep "^${DIR_PATH}$" "${TMP_PATH}/${LOCK_FILE_NAME}") == "$DIR_PATH" ]]; then
			echo "The directory is already locked by another script run! Exiting..."
			echo
			exit 0
		fi
	fi
}

savePerms()
{
	if [[ "$OSTYPE" == "linux-gnu"* ]]; then
		CUR_OWNER=$(stat -c "%U:%G" "$IMAGE")
		CUR_PERMS=$(stat -c "%a" "$IMAGE")
	else
		CUR_OWNER=$(ls -l "$IMAGE" | awk '{print $3":"$4}')
		CUR_PERMS=$(stat -f "%Lp" "$IMAGE")
	fi
}

restorePerms()
{
	chown $CUR_OWNER "$IMAGE"
	chmod $CUR_PERMS "$IMAGE"
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
	echo "    -ext <list>,            Comma separated list of script's extensions to "
	echo "    --extensions=<list>     enable. Script's extensions disabled by default. "
	echo "                            Use \"all\" to enable all found extensions."
	echo
	echo "    --unlock                Manually delete target dir from lockfile if "
	echo "                            previous script launch was interrupted "
	echo "                            incorrectly or killed by system. You must use "
	echo "                            this option with -p|--path option."
	echo
}

# Define default script vars
BASH_MIN_VERSION=4
TMP_PATH="/tmp"
GIT_URL="https://github.com/zevilz/zImageOptimizer"
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
ALL_FOUND=1
PARAMS_NUM=$#
CUR_DIR=$(pwd)
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
TIME_MARKER_PATH=""
TIME_MARKER_NAME=".timeMarker"
LOCK_FILE_NAME="zio.lock"
UNLOCK=0

# Define CRON and direct using styling
if [ "Z$(ps o comm="" -p $(ps o ppid="" -p $$))" == "Zcron" -o \
     "Z$(ps o comm="" -p $(ps o ppid="" -p $(ps o ppid="" -p $$)))" == "Zcron" ]; then
	SETCOLOR_SUCCESS=
	SETCOLOR_FAILURE=
	SETCOLOR_NORMAL=
	BOLD_TEXT=
	NORMAL_TEXT=
else
	SETCOLOR_SUCCESS="echo -en \\033[1;32m"
	SETCOLOR_FAILURE="echo -en \\033[1;31m"
	SETCOLOR_NORMAL="echo -en \\033[0;39m"
	BOLD_TEXT=$(tput bold)
	NORMAL_TEXT=$(tput sgr0)
fi

checkBashVersion

# Parse options
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

	elif [ "${1#--extensions=}" != "$1" ] ; then
		ENABLED_EXTENSIONS="${1#--extensions=}"
	elif [ "$1" = "-ext" ] ; then
		shift ; ENABLED_EXTENSIONS="$1"

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

	elif [[ "$1" = "--unlock" ]] ; then
		UNLOCK=1

	elif [ -z "$1" ] ; then
		break
	else
		echo
		$SETCOLOR_FAILURE
		echo "Unknown key detected!" 1>&2
		$SETCOLOR_NORMAL
		usage
		exit 1
	fi
	shift
done

# Enabled extensions
checkEnabledExtensions

# Hook: after-parse-options
includeExtensions after-parse-options

# Register binary paths
BINARY_PATHS="/bin /usr/bin /usr/local/bin"

# Hook: after-init-binary-paths
includeExtensions after-init-binary-paths

# Generate binary paths array
BINARY_PATHS=$(echo $BINARY_PATHS | sed 's/\/\ /\ /g' | sed 's/\/$/\ /')
BINARY_PATHS_ARRAY=($BINARY_PATHS)

# Register image types
declare -A IMG_TYPES_ARR
IMG_TYPES_ARR[JPG]="JPG"
IMG_TYPES_ARR[PNG]="PNG"
IMG_TYPES_ARR[GIF]="GIF"

# Hook: after-init-image-types
includeExtensions after-init-image-types

# Check images types array
if [ ${#IMG_TYPES_ARR[@]} -eq 0 ]; then
	echo
	$SETCOLOR_FAILURE
	echo "Not found any registered images types!"
	echo "Please check your extensions!"
	$SETCOLOR_NORMAL
	echo
	exit 1
fi

# Register tools
declare -A TOOLS
if ! [ -z "${IMG_TYPES_ARR[JPG]}" ]; then
	TOOLS[JPG]="jpegoptim jpegtran djpeg cjpeg"
fi
if ! [ -z "${IMG_TYPES_ARR[PNG]}" ]; then
	TOOLS[PNG]="pngcrush optipng pngout advpng"
fi
if ! [ -z "${IMG_TYPES_ARR[GIF]}" ]; then
	TOOLS[GIF]="gifsicle"
fi

# Hook: after-init-tools
includeExtensions after-init-tools

# Check tools array
if [ ${#TOOLS[@]} -eq 0 ]; then
	echo
	$SETCOLOR_FAILURE
	echo "Not found any registered optimizing tools!"
	echo "Please check your extensions!"
	$SETCOLOR_NORMAL
	echo
	exit 1
fi

# Generate tools array
TOOLS_ARRAY=($(echo ${TOOLS[@]}))

# Register images extensions
declare -A FIND_EXT_ARR
FIND_EXT=
if ! [ -z "${IMG_TYPES_ARR[JPG]}" ]; then
	FIND_EXT_ARR[JPG]='JPG JPEG jpg jpeg'
fi
if ! [ -z "${IMG_TYPES_ARR[PNG]}" ]; then
	FIND_EXT_ARR[PNG]='PNG png'
fi
if ! [ -z "${IMG_TYPES_ARR[GIF]}" ]; then
	FIND_EXT_ARR[GIF]='GIF gif'
fi

# Hook: after-init-img-ext
includeExtensions after-init-img-ext

# Check images extensions array
if [ ${#FIND_EXT_ARR[@]} -eq 0 ]; then
	echo
	$SETCOLOR_FAILURE
	echo "Not found any registered images extensions!"
	echo "Please check your extensions!"
	$SETCOLOR_NORMAL
	echo
	exit 1
fi

# Generate names for find command
for FIND_EXT_ITEM in "${FIND_EXT_ARR[@]}"; do
	FIND_EXT="${FIND_EXT} ${FIND_EXT_ITEM}"
done
FIND_NAMES=$(echo -n '-name *.'; joinBy ' -or -name *.' $FIND_EXT)

# Register OS-based dependencies
declare -A DEPS_DEBIAN_ARR
declare -A DEPS_REDHAT_ARR
declare -A DEPS_MACOS_ARR
DEPS_DEBIAN="wget autoconf automake libtool make bc"
DEPS_REDHAT="wget autoconf automake libtool make bc"
DEPS_MACOS=""
if ! [ -z "${TOOLS[JPG]}" ]; then
	DEPS_DEBIAN_ARR[JPG]="jpegoptim libjpeg-progs"
	DEPS_REDHAT_ARR[JPG]="jpegoptim libjpeg*"
	DEPS_MACOS_ARR[JPG]="jpegoptim libjpeg"
fi
if ! [ -z "${TOOLS[PNG]}" ]; then
	DEPS_DEBIAN_ARR[PNG]="pngcrush optipng advancecomp"
	DEPS_REDHAT_ARR[PNG]="pngcrush optipng advancecomp"
	DEPS_MACOS_ARR[PNG]="pngcrush optipng advancecomp jonof/kenutils/pngout"
fi
if ! [ -z "${TOOLS[GIF]}" ]; then
	DEPS_DEBIAN_ARR[GIF]="gifsicle"
	DEPS_REDHAT_ARR[GIF]="gifsicle"
	DEPS_MACOS_ARR[GIF]="gifsicle"
fi

# Hook: after-init-deps
includeExtensions after-init-deps

# Generate OS-based dependencies
for DEPS_DEBIAN_ITEM in "${DEPS_DEBIAN_ARR[@]}"; do
	DEPS_DEBIAN="${DEPS_DEBIAN} ${DEPS_DEBIAN_ITEM}"
done
for DEPS_REDHAT_ITEM in "${DEPS_REDHAT_ARR[@]}"; do
	DEPS_REDHAT="${DEPS_REDHAT} ${DEPS_REDHAT_ITEM}"
done
for DEPS_MACOS_ITEM in "${DEPS_MACOS_ARR[@]}"; do
	DEPS_MACOS="${DEPS_MACOS} ${DEPS_MACOS_ITEM}"
done

# Register min versions of Linux distros. Must be integer.
MIN_VERSION_DEBIAN=7
MIN_VERSION_UBUNTU=14
MIN_VERSION_FEDORA=24
MIN_VERSION_RHEL=6
MIN_VERSION_CENTOS=6

# Register min version MacOS.
MIN_VERSION_MACOS=10

# Register min version of FreeBSD.
MIN_VERSION_FREEBSD=10

# Hook: after-init-deps-vars
includeExtensions after-init-deps-vars

# Hook: after-init-vars
includeExtensions after-init-vars

# Show help
if [[ $HELP -eq 1 || $PARAMS_NUM -eq 0 ]]; then
	usage
	exit 0
fi

# Show version
if [ $SHOW_VERSION -eq 1 ]; then
	CUR_VERSION=$(grep 'Version:\ ' $0 | cut -d ' ' -f3)
	echo $CUR_VERSION
	exit 0
fi

# Checking input data
if [ $CHECK_ONLY -eq 0 ]; then

	DIR_PATH=$(echo "$DIR_PATH" | sed 's/\/$//')
	checkParm "$DIR_PATH" "Path to files not set in -p(--path) option!"
	checkDir "$DIR_PATH"
	cdAndCheck "$DIR_PATH"
	checkDirPermissions "$DIR_PATH"

	TMP_PATH=$(echo "$TMP_PATH" | sed 's/\/$//')
	checkDir "$TMP_PATH" "Directory for temporary files not found!"
	cdAndCheck "$TMP_PATH" "Can't get up in a directory for temporary files!"
	checkDirPermissions "$TMP_PATH" "Current user have no permissions to directory for temporary files!"

	if [[ $PERIOD != 0 && $NEW_ONLY -gt 0 ]]; then
		echo
		$SETCOLOR_FAILURE
		echo "It is impossible to use options -t(--time) and -n(--new-only) together! Set only one of it."
		$SETCOLOR_NORMAL
		echo
		exit 1
	fi

	if ! [ -z "$TIME_MARKER" ]; then
		if [ $NEW_ONLY -eq 0 ]; then
			echo
			$SETCOLOR_FAILURE
			echo "You can't use option -m(--time-marker) without -n(--new-only) option!"
			$SETCOLOR_NORMAL
			echo
			exit 1
		fi
	fi

	if [ $PERIOD != 0 ]; then

		if ! [[ $PERIOD =~ ^-?[0-9]+(m|h|d)$ ]]; then
			echo
			$SETCOLOR_FAILURE
			echo "Wrong format of period!"
			$SETCOLOR_NORMAL
			echo
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
		checkDir "$TIME_MARKER_FULL_PATH_DIR" "Directory for time marker not found!"
		cdAndCheck "$TIME_MARKER_FULL_PATH_DIR" "Can't get up in a directory for time marker!"
		checkUserTimeMarker
		checkDirPermissions "$TIME_MARKER_FULL_PATH_DIR" "Current user have no permissions to directory for time marker!"
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

	# Hook: after-check-input-data
	includeExtensions after-check-input-data

fi

echo

# Checking tools
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

# Dialogs after checking tools
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
					echo
					exit 0
					;;
				2) echo
					installDeps
					echo "Exiting..."
					echo
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
					echo
					exit 0
					;;
				1) echo
					installDeps
					echo "Exiting..."
					echo
					exit 0
					;;
				*) echo
					echo "Exiting..."
					echo
					exit 0
					;;
			esac
		fi
	else
		if [ $CHECK_ONLY -eq 1 ]; then
			installDeps
			echo "Exiting..."
			echo
			exit 0
		fi
	fi
fi

# Return to script dir to prevent find errors
cd "$SCRIPT_PATH"

# Find images
IMAGES=$(find "$DIR_PATH" $FIND_INCLUDE \( $FIND_NAMES \) | findExclude)

# Num of images
IMAGES_TOTAL=$(echo "$IMAGES" | wc -l)

# Preoptimize vars
IMAGES_OPTIMIZED=0
IMAGES_CURRENT=0
START_TIME=$(date +%s)

# Hook: init-loop-vars-after
includeExtensions init-loop-vars-after

# If images found
if ! [ -z "$IMAGES" ]; then

	# Unlock
	if [[ $UNLOCK -eq 1 ]]; then
		unlockDir
	fi

	# Check isset working dir in lock file
	checkDirLock

	# Lock working dir in lock file
	lockDir

	# Update time marker
	updateTimeMarker

	echo "Optimizing..."

	# Init stat vars
	INPUT=0
	OUTPUT=0
	SAVED_SIZE=0

	# Main optimize loop
	echo "$IMAGES" | ( \
		while read IMAGE ; do

			# Additional vars for using hooks
			OPTIMIZE=1
			OPTIMIZE_JPG=1
			OPTIMIZE_PNG=1
			OPTIMIZE_GIF=1
			RESTORE_IMAGE_CHECK=1
			BACKUP=1
			CALCULATE_STATS=1
			SHOW_OPTIMIZE_RESULT=1

			# Internal vars
			RESTORE_IMAGE_PERMS=1
			UPDATE_IMAGE_MODIFY_TIME=1

			# Process counter
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

			# Sizes before optimizing
			SIZE_BEFORE=$(wc -c "$IMAGE" | awk '{print $1}')
			SIZE_BEFORE_SCALED=$(echo "scale=1; $SIZE_BEFORE/1024" | bc | sed 's/^\./0./')
			INPUT=$(echo "$INPUT+$SIZE_BEFORE" | bc)

			# Get image extension
			EXT=${IMAGE##*.}

			if [ $BACKUP -eq 1 ]; then

				# Save permissions
				savePerms

				# Backup original file
				cp -fp "$IMAGE" "$TMP_PATH/$(basename "$IMAGE").bkp"

			fi

			# Hook: optim-before
			includeExtensions optim-before

			# JPEG
			if [[ $EXT == "jpg" || $EXT == "jpeg" || $EXT == "JPG" || $EXT == "JPEG" ]]; then

				# Hook: optim-jpg-before
				includeExtensions optim-jpg-before

				if [[ $OPTIMIZE -eq 1 && $OPTIMIZE_JPG -eq 1 ]]; then

					optimJPG "$IMAGE"

				fi

				# Hook: optim-jpg-after
				includeExtensions optim-jpg-after

			# PNG
			elif [[ $EXT == "png" || $EXT == "PNG" ]]; then

				# Hook: optim-png-before
				includeExtensions optim-png-before

				if [[ $OPTIMIZE -eq 1 && $OPTIMIZE_PNG -eq 1 ]]; then

					optimPNG "$IMAGE"

				fi

				# Hook: optim-png-after
				includeExtensions optim-png-after

			# GIF
			elif [[ $EXT == "gif" || $EXT == "GIF" ]]; then

				# Hook: optim-gif-before
				includeExtensions optim-gif-before

				if [[ $OPTIMIZE -eq 1 && $OPTIMIZE_GIF -eq 1 ]]; then

					optimGIF "$IMAGE"

				fi

				# Hook: optim-gif-after
				includeExtensions optim-gif-after

			fi

			# Hook: optim-after
			includeExtensions optim-after

			# Sizes after
			if [ $CALCULATE_STATS -eq 1 ]; then
				SIZE_AFTER=$(wc -c "$IMAGE" | awk '{print $1}')
				SIZE_AFTER_SCALED=$(echo "scale=1; $SIZE_AFTER/1024" | bc | sed 's/^\./0./')
			fi

			if [ $BACKUP -eq 1 ]; then

				# Restore original if it smaller as optimized
				if [ $RESTORE_IMAGE_CHECK -eq 1 ]; then

					if [ $SIZE_BEFORE -le $SIZE_AFTER ]; then
						cp -fp "$TMP_PATH/$(basename "$IMAGE").bkp" "$IMAGE"
						RESTORE_IMAGE_PERMS=0
						UPDATE_IMAGE_MODIFY_TIME=0
					fi

				fi

				# Remove backup if exists
				if [ -f "$TMP_PATH/$(basename "$IMAGE").bkp" ]; then
					rm "$TMP_PATH/$(basename "$IMAGE").bkp"
				fi

			fi

			# Restore image permissions
			if [ $RESTORE_IMAGE_PERMS -eq 1 ]; then
				restorePerms
			fi

			# Update modify time from time marker
			if [ $UPDATE_IMAGE_MODIFY_TIME -eq 1 ]; then
				updateModifyTime
			fi

			# Calculate stats
			if [ $CALCULATE_STATS -eq 1 ]; then
				if [ $SIZE_BEFORE -le $SIZE_AFTER ]; then
					OUTPUT=$(echo "$OUTPUT+$SIZE_BEFORE" | bc)
				else
					OUTPUT=$(echo "$OUTPUT+$SIZE_AFTER" | bc)
					SIZE_DIFF=$(echo "$SIZE_BEFORE-$SIZE_AFTER" | bc)
					SAVED_SIZE=$(echo "$SAVED_SIZE+$SIZE_DIFF" | bc)
					IMAGES_OPTIMIZED=$(echo "$IMAGES_OPTIMIZED+1" | bc)
				fi
			fi

			# Optimize results and sizes
			if [ $SHOW_OPTIMIZE_RESULT -eq 1 ]; then
				if [ $LESS -eq 0 ]; then
					if [ $SIZE_BEFORE -le $SIZE_AFTER ]; then
						$SETCOLOR_FAILURE
						echo -n "[NOT OPTIMIZED]"
						$SETCOLOR_NORMAL
						echo " ${SIZE_BEFORE_SCALED}Kb"
					else
						$SETCOLOR_SUCCESS
						echo -n "[OPTIMIZED]"
						$SETCOLOR_NORMAL
						echo " ${SIZE_BEFORE_SCALED}Kb -> ${SIZE_AFTER_SCALED}Kb"
					fi
				fi
			else
				echo
			fi

		done

		# Hook: total-info-before
		includeExtensions total-info-before

		# Total info
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

		# Hook: total-info-time-before
		includeExtensions total-info-time-before

		END_TIME=$(date +%s)
		TOTAL_TIME=$(echo "$END_TIME-$START_TIME" | bc)
		echo -n "Total optimizing time: "
		readableTime $TOTAL_TIME

		# Hook: total-info-after
		includeExtensions total-info-after

	) # End of loop process. Further variable variables inside loop will not be available

	# Time marker fix
	fixTimeMarker

	# Unlock working dir in lock file
	unlockDir

else

	echo "No input images found."

fi

echo

cd "$CUR_DIR"

exit 0
