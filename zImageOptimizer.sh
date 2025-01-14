#!/usr/bin/env bash
# Simple image optimizer for JPEG, PNG and GIF images.
# URL: https://github.com/zevilz/zImageOptimizer
# Author: Alexandr "zEvilz" Emshanov
# License: MIT
# Version: 0.11.0

# Core utility functions
initializeVariables() {
	# Add trap handler for Ctrl+C
	trap cleanup SIGINT

	IMAGES_OPTIMIZED=0
	IMAGES_CURRENT=0
	START_TIME=$(date +%s)
	INPUT=0
	OUTPUT=0
	SAVED_SIZE=0

	# Export variables so they persist across subshells
	export IMAGES_OPTIMIZED
	export IMAGES_CURRENT
	export INPUT
	export OUTPUT
	export SAVED_SIZE
}

# Add cleanup function
cleanup() {
	echo -e "\nScript interrupted by user. Cleaning up..."

	# Remove all temporary files
	rm -f "${TMP_PATH}/stats.tmp" "${TMP_PATH}/progress.tmp"

	# Remove any backup files
	if [ "$BACKUP" = "1" ]; then
		rm -f "$TMP_PATH"/*.bkp
	fi

	# Remove any PPM temporary files from failed optimizations
	rm -f "${TMP_PATH}"/*.ppm

	# Unlock the directory
	unlockDir

	# Exit with error code
	exit 1
}

showProgressBar() {
	local current=$1
	local total=$2
	local width=50

	# Prevent division by zero and invalid inputs
	if [ -z "$total" ] || [ -z "$current" ] || [ "$total" -le 0 ]; then
		return 1
	fi

	# Convert inputs to integers
	current=$(($current + 0))
	total=$(($total + 0))

	# Ensure current doesn't exceed total
	if [ "$current" -gt "$total" ]; then
		current=$total
	fi

	local percentage=$(((current * 100) / total))
	local completed=$(((width * current) / total))

	printf "\r[" >&2
	printf "%${completed}s" '' | tr ' ' '#' >&2
	printf "%$((width - completed))s" '' | tr ' ' '-' >&2
	printf "] %3d%% (%d/%d)" "$percentage" "$current" "$total" >&2
}

calculateStats() {
	local size_before=$1
	local size_after=$2

	# Read current stats
	read cur_input cur_output cur_saved cur_optimized <"${TMP_PATH}/stats.tmp"

	# Update stats
	cur_input=$((cur_input + size_before))

	if [ $size_before -le $size_after ]; then
		# If not optimized, use original size
		cur_output=$((cur_output + size_before))
		echo "$cur_input $cur_output $cur_saved $cur_optimized" >"${TMP_PATH}/stats.tmp"
		return 1
	else
		# If optimized, use new size and update stats
		cur_output=$((cur_output + size_after))
		cur_saved=$((cur_saved + (size_before - size_after)))
		cur_optimized=$((cur_optimized + 1))
		echo "$cur_input $cur_output $cur_saved $cur_optimized" >"${TMP_PATH}/stats.tmp"
		return 0
	fi
}

displayOptimizationResult() {
	local size_before=$1
	local size_after=$2
	local failed_status=$3
	local size_before_scaled=$(echo "scale=1; $size_before/1024" | bc | sed 's/^\./0./')
	local size_after_scaled=$(echo "scale=1; $size_after/1024" | bc | sed 's/^\./0./')

	if [ "${failed_status:-0}" -ne 0 ]; then
		printf "%s[FAILED]%s" "$($SETCOLOR_FAILURE)" "$($SETCOLOR_NORMAL)"
	elif [ $size_before -le $size_after ]; then
		printf "%s[NOT OPTIMIZED]%s ${size_before_scaled}Kb" "$($SETCOLOR_FAILURE)" "$($SETCOLOR_NORMAL)"
	else
		printf "%s[OPTIMIZED]%s ${size_before_scaled}Kb -> ${size_after_scaled}Kb" "$($SETCOLOR_SUCCESS)" "$($SETCOLOR_NORMAL)"
	fi
	echo
}

# Image handling functions
handleBackup() {
	local image="$1"
	if [ "$BACKUP" = "1" ]; then
		savePerms
		cp -fp "$image" "$TMP_PATH/$(basename "$image").bkp"
	fi
}

restoreBackup() {
	local image="$1"
	local size_before="$2"
	local size_after="$3"

	if [ "$BACKUP" = "1" ]; then
		if [ "$RESTORE_IMAGE_CHECK" = "1" ] && [ "$size_before" -le "$size_after" ]; then
			cp -fp "$TMP_PATH/$(basename "$image").bkp" "$image"
			return 0
		fi
		rm -f "$TMP_PATH/$(basename "$image").bkp"
	fi
	return 1
}

# Optimization functions
optimizeImage() {
	local image="$1"
	local ext="${image##*.}"
	ext="${ext,,}" # Convert to lowercase

	case "$ext" in
	jpg | jpeg | jpe)
		optimJPG "$image"
		;;
	png)
		optimPNG "$image"
		;;
	gif)
		optimGIF "$image"
		;;
	esac
}

# Main processing function
processImage() {
	local image="$1"
	local failed=0

	if [ ! -f "$image" ]; then
		printf "%s[SKIPPING - NOT EXISTS]%s\n" "$($SETCOLOR_FAILURE)" "$($SETCOLOR_NORMAL)"
		return 1
	fi

	# Get initial size
	local size_before=$(wc -c "$image" | awk '{print $1}')

	# Backup and optimize
	handleBackup "$image"
	optimizeImage "$image"
	local failed_status=$?

	# Get final size and calculate stats
	local size_after=$(wc -c "$image" | awk '{print $1}')

	# Restore backup if needed
	if ! restoreBackup "$image" "$size_before" "$size_after"; then
		restorePerms
		updateModifyTime
	fi

	# Calculate and display results
	calculateStats "$size_before" "$size_after"
	[ $LESS -eq 0 ] && displayOptimizationResult "$size_before" "$size_after" "$failed_status"

	return 0
}

# Main optimization loop
processImages() {
	local images="$1"
	local total=$(echo "$images" | wc -l)

	echo "Optimizing..."

	initializeVariables
	export IMAGES_TOTAL=$total

	# Change to target directory before processing
	cd "$FULL_DIR_PATH" || exit 1

	# Convert input to array, handling spaces correctly
	mapfile -t image_array < <(echo "$images" | grep -v '^$')

	# Initialize stats file with zeros
	echo "0 0 0 0" >"${TMP_PATH}/stats.tmp"
	echo "0" >"${TMP_PATH}/progress.tmp"

	# Process each image using array
	for ((i = 0; i < ${#image_array[@]}; i++)); do
		image="${image_array[$i]}"

		IMAGES_CURRENT=$((i + 1))
		echo "$IMAGES_CURRENT" >"${TMP_PATH}/progress.tmp"

		if [ $LESS -eq 0 ]; then
			showProgressBar "$IMAGES_CURRENT" "$total"
		fi

		processImage "$image"
		if [ $LESS -eq 0 ]; then
			printf "\r"
		fi
	done

	# Read final stats
	read INPUT OUTPUT SAVED_SIZE IMAGES_OPTIMIZED <"${TMP_PATH}/stats.tmp"

	# Clean up
	rm -f "${TMP_PATH}/progress.tmp" "${TMP_PATH}/stats.tmp"

	# Return to original directory
	cd "$ORIGINAL_DIR" || exit 1

	displayFinalStats
}

# Statistics display
displayFinalStats() {
	echo -e "\n\nOptimization Summary:"
	echo "----------------------"
	printf "Input: %s\n" "$(readableSize $INPUT)"
	printf "Output: %s\n" "$(readableSize $OUTPUT)"
	printf "Saved: %s\n" "$(readableSize $SAVED_SIZE)"
	if [ "$INPUT" -gt 0 ]; then
		echo " ($(echo "scale=2; ($INPUT-$OUTPUT)*100/$INPUT" | bc | sed 's/^\./0./')%)"
	else
		echo " (0%)"
	fi
	echo "Files Optimized: $IMAGES_OPTIMIZED / $IMAGES_TOTAL"

	END_TIME=$(date +%s)
	TOTAL_TIME=$((END_TIME - START_TIME))
	printf "Total Time: %s" "$(readableTime $TOTAL_TIME)"
}

sayWait() {
	if [ "$NO_ASK" -eq 1 ]; then
		return 0
	fi
	local AMSURE
	[ -n "$1" ] && echo "$@" 1>&2
	read -n 1 -p "Press any key to continue..." AMSURE
	echo "" 1>&2
}

cdAndCheck() {
	local target_dir
	target_dir=$(readlink -f "$1") || {
		echo "Failed to resolve path: $1"
		exit 1
	}

	if [ $DEBUG -eq 1 ]; then
		echo "Debug: Attempting cd to: '$target_dir'"
	fi

	cd "$target_dir" 2>/dev/null || {
		echo
		$SETCOLOR_FAILURE
		if [ -z "$2" ]; then
			echo "Can't change to directory: '$target_dir'" 1>&2
			echo "Current directory: $(pwd)" 1>&2
		else
			echo "$2" 1>&2
		fi
		$SETCOLOR_NORMAL
		echo
		exit 1
	}
}

checkDir() {
	if ! [ -d "$1" ]; then
		echo
		$SETCOLOR_FAILURE
		echo "${2:-"Directory $1 not found!"}" 1>&2
		$SETCOLOR_NORMAL
		echo
		exit 1
	fi
}

checkDirPermissions() {
	local test_file="$1/checkDirPermissions"
	cd "$1" 2>/dev/null
	touch "$test_file" 2>/dev/null
	if ! [ -f "$test_file" ]; then
		echo
		$SETCOLOR_FAILURE
		if [ -z "$2" ]; then
			echo "Current user does not have write permission to the directory $1!" 1>&2
		else
			echo "$2" 1>&2
		fi
		$SETCOLOR_NORMAL
		echo
		exit 1
	else
		rm "$test_file"
	fi
}

checkParm() {
	if [ -z "$1" ]; then
		echo
		$SETCOLOR_FAILURE
		echo "${2:-"Parameter not set!"}" 1>&2
		$SETCOLOR_NORMAL
		echo
		exit 1
	fi
}

inArray() {
	local match="$1"
	shift
	local IFS="|"
	[[ "$*" =~ (^|[|])$match($|[|]) ]]
}

installMozJPEG() {
	$SUDO apt-get install cmake nasm libpng-dev -y || return 1

	git clone https://github.com/mozilla/mozjpeg.git || return 1
	cd mozjpeg || return 1
	mkdir -p build && cd build || return 1

	cmake -G"Unix Makefiles" \
		-DCMAKE_BUILD_TYPE=Release \
		-DENABLE_STATIC=TRUE \
		-DCMAKE_INSTALL_PREFIX=/usr/local \
		.. || return 1

	make || return 1
	$SUDO make install || return 1
	cd ../..
	$SUDO rm -rf mozjpeg
	return 0
}

installDeps() {
	PLATFORM="unknown"
	PLATFORM_ARCH="unknown"
	PLATFORM_SUPPORT=0
	PNGCRUSH_VERSION=1.8.13
	ADVANCECOMP_VERSION=2.6
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
			[ zz$(type -t passed 2>/dev/null) == "zzfunction" ] && PLATFORM_PKG="redhat"
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

		# Then test against Debian, Ubuntu and friends
		elif [ -r /lib/lsb/init-functions ]; then

			source /lib/lsb/init-functions
			[ zz$(type -t log_begin_msg 2>/dev/null) == "zzfunction" ] && PLATFORM_PKG="debian"
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

		# Hook: before-install-deps
		includeExtensions before-install-deps

		if [ $PLATFORM == "linux" ]; then

			# Hook: before-install-deps-linux
			includeExtensions before-install-deps-linux

			if [ $PLATFORM_PKG == "debian" ]; then

				# Hook: before-install-deps-debian
				includeExtensions before-install-deps-debian

				$SUDO apt-get update

				# Handle mozjpeg installation separately
				if [[ "$DEPS_DEBIAN" == *"mozjpeg"* ]]; then
					DEPS_DEBIAN=${DEPS_DEBIAN/mozjpeg/}
					$SUDO apt-get install $DEPS_DEBIAN -y
					installMozJPEG
				else
					$SUDO apt-get install $DEPS_DEBIAN -y
				fi

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
					for p in "${!BINARY_PATHS_ARRAY[@]}"; do
						if [ -f "${BINARY_PATHS_ARRAY[$p]}/pngcrush" ]; then
							ISSET_pngcrush=1
						fi
					done
					if ! [ -z $ISSET_pngcrush ] && [ $ISSET_pngcrush -eq 0 ]; then
						wget https://downloads.sourceforge.net/project/pmt/pngcrush/$PNGCRUSH_VERSION/pngcrush-$PNGCRUSH_VERSION.tar.gz
						tar -zxvf pngcrush-$PNGCRUSH_VERSION.tar.gz
						rm pngcrush-$PNGCRUSH_VERSION.tar.gz
						cd pngcrush-$PNGCRUSH_VERSION
						make
						$SUDO cp pngcrush /bin/
						cd ../
						rm -rf pngcrush-$PNGCRUSH_VERSION
					fi

					for p in "${!BINARY_PATHS_ARRAY[@]}"; do
						if [ -f "${BINARY_PATHS_ARRAY[$p]}/advpng" ]; then
							ISSET_advpng=1
						fi
					done
					if ! [ -z $ISSET_advpng ] && [ $ISSET_advpng -eq 0 ]; then
						$SUDO yum install zlib-devel gcc-c++ -y
						wget https://github.com/amadvance/advancecomp/releases/download/v$ADVANCECOMP_VERSION/advancecomp-$ADVANCECOMP_VERSION.tar.gz
						tar -zxvf advancecomp-$ADVANCECOMP_VERSION.tar.gz
						rm advancecomp-$ADVANCECOMP_VERSION.tar.gz
						cd advancecomp-$ADVANCECOMP_VERSION
						./configure
						make
						$SUDO make install
						cd ../
						rm -rf advancecomp-$ADVANCECOMP_VERSION
					fi
				fi

				if [[ "$DEPS_REDHAT" == *"mozjpeg"* ]]; then
					DEPS_REDHAT=${DEPS_REDHAT/mozjpeg/}
					$SUDO yum install $DEPS_REDHAT -y
					installMozJPEG
				else
					$SUDO yum install $DEPS_REDHAT -y
				fi
			fi

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

			for p in "${!BINARY_PATHS_ARRAY[@]}"; do
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

		# Hook: after-install-deps
		includeExtensions after-install-deps

	else
		echo "Your platform is not supported! Please install dependaces manually."
		echo "Info: $GIT_URL#manual-installing-dependences"
		echo
	fi
}

checkBashVersion() {
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
			0)
				echo
				echo "Exiting..."
				echo
				exit 0
				;;
			1)
				echo
				installBashMacOS
				echo "Exiting..."
				echo
				exit 0
				;;
			*)
				echo
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

installBashMacOS() {
	checkHomebrew
	brew install bash

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

checkHomebrew() {
	for p in "${!BINARY_PATHS_ARRAY[@]}"; do
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

getTimeMarkerPath() {
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

checkUserTimeMarker() {
	if [[ $TIME_MARKER =~ ^-?.*\/$ ]]; then
		echo
		$SETCOLOR_FAILURE
		echo "Time marker filename not set in given path!" 1>&2
		$SETCOLOR_NORMAL
		echo
		exit 1
	fi
}

checkTimeMarkerPermissions() {
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
		if date --version >/dev/null 2>/dev/null; then
			touch -t $(date '+%Y%m%d%H%M.%S' -d @$TIME_MARKER_MODIFIED) "$1" >/dev/null # GNU version of date
		else
			touch -t $(date -r $TIME_MARKER_MODIFIED +%Y%m%d%H%M.%S) "$1" >/dev/null # Non GNU version of date
		fi
	fi
}

updateTimeMarker() {
	if [ $NEW_ONLY -eq 1 ]; then
		touch -m "$TIME_MARKER_FULL_PATH" >/dev/null
		if [ $TIME_MARKER_ISSET -eq 1 ]; then
			echo "Time marker updated."
		else
			echo "Time marker created."
		fi
		echo
	fi
}

fixTimeMarker() {
	if [ $NEW_ONLY -eq 1 ]; then
		if [[ "$OSTYPE" == "darwin"* ]]; then
			TIME_MARKER_MODIFIED_TIME=$(stat -t %s -f %m -- "$TIME_MARKER_FULL_PATH")
		else
			TIME_MARKER_MODIFIED_TIME=$(date -r "$TIME_MARKER_FULL_PATH" +%s)
		fi

		TIME_MARKER_MODIFIED_TIME=$(echo "$TIME_MARKER_MODIFIED_TIME+1" | bc)

		if date --version >/dev/null 2>/dev/null; then
			touch -t $(date '+%Y%m%d%H%M.%S' -d @$TIME_MARKER_MODIFIED_TIME) "$TIME_MARKER_FULL_PATH" >/dev/null # GNU version of date
		else
			touch -t $(date -r $TIME_MARKER_MODIFIED_TIME +%Y%m%d%H%M.%S) "$TIME_MARKER_FULL_PATH" >/dev/null # Non GNU version of date
		fi
	fi
}

updateModifyTime() {
	if [ $NEW_ONLY -eq 1 ] && [ -n "$image" ] && [ -f "$image" ]; then
		touch "$image" -r "$TIME_MARKER_FULL_PATH" >/dev/null 2>&1
	fi
}

optimJpegoptim() {
	if [ $DEBUG -eq 1 ]; then
		printf "\Using: jpegoptim"
	fi

	jpegoptim --strip-all "$1" >/dev/null
}

optimJpegtran() {
	if [ $DEBUG -eq 1 ]; then
		printf "\nUsing: jpegtran"
	fi

	jpegtran -progressive -copy none -optimize "$1" >/dev/null
}

optimXjpeg() {
	if [ $DEBUG -eq 1 ]; then
		printf "\nUsing: cjpeg\nResult: "
	fi

	local image="$1"
	local temp_file="$TMP_PATH/$(basename "$image").ppm"

	# Decompress with djpeg, capturing any error output
	if ! djpeg -outfile "$temp_file" "$image" 2>/dev/null; then
		[ $DEBUG -eq 1 ] && echo "djpeg failed to process $image"
		rm -f "$temp_file" # Cleanup empty file if it exists
		return 1
	fi

	# Check if temp file exists and has size
	if [ ! -s "$temp_file" ]; then
		[ $DEBUG -eq 1 ] && echo "Temp file missing or empty: $temp_file"
		rm -f "$temp_file" # Cleanup empty file if it exists
		return 1
	fi

	# Use mozjpeg-specific options if available
	if cjpeg -help 2>&1 | grep -q -- "-quality"; then
		cjpeg -quality 85 -optimize -progressive -outfile "$image" "$temp_file" >/dev/null 2>&1
	else
		cjpeg -optimize -progressive -outfile "$image" "$temp_file" >/dev/null 2>&1
	fi

	local status=$?
	rm -f "$temp_file"
	return $status
}

optimPngcrush() {
	if [ $DEBUG -eq 1 ]; then
		printf "\nUsing: pngcrush\nResult: "
	fi
	IMAGE="$1"
	IMAGE_DIR=$(dirname "$IMAGE")
	cd "$IMAGE_DIR"
	pngcrush -rem gAMA -rem cHRM -rem iCCP -rem sRGB -brute -l 9 -reduce -q -s -ow "$IMAGE" >/dev/null
}

optimOptipng() {
	if [ $DEBUG -eq 1 ]; then
		printf "\nUsing: optipng\nResult: "
	fi

	OPTIPNG_V=$(optipng -v | head -n1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | cut -d '.' -f2)
	if ! [ -z $OPTIPNG_V ]; then
		if [ $OPTIPNG_V -ge 7 ]; then
			optipng -strip all -o7 -q "$1" >/dev/null
		else
			optipng -o7 -q "$1" >/dev/null
		fi
	else
		optipng -o7 -q "$1" >/dev/null
	fi
}

optimPngout() {
	if [ $DEBUG -eq 1 ]; then
		printf "\nUsing: pngout\nResult: "
	fi

	pngout -q -y -k0 -s0 "$1" >/dev/null
}

optimAdvpng() {
	if [ $DEBUG -eq 1 ]; then
		printf "\nUsing: advpng\nResult: "
	fi

	advpng -z -4 "$1" >/dev/null
}

optimGifsicle() {
	if [ $DEBUG -eq 1 ]; then
		printf "\nUsing: gifsicle\nResult: "
	fi

	gifsicle --optimize=3 -b "$1" >/dev/null
	#gifsicle --optimize=3 --lossy=30 -b "$IMAGE" # for lossy optimize
}

optimJPG() {
	if [ $DEBUG -eq 1 ]; then
		printf "\nInput image: $1"
	fi

	if [[ $ISSET_djpeg -eq 1 && $ISSET_cjpeg -eq 1 ]]; then
		optimXjpeg "$1"
	elif [[ $ISSET_jpegoptim -eq 1 ]]; then
		optimJpegoptim "$1"
	elif [[ $ISSET_jpegtran -eq 1 ]]; then
		optimJpegtran "$1"
	else
		echo "No JPEG optimizer found"
		return 1
	fi
}

optimPNG() {
	if [ $DEBUG -eq 1 ]; then
		printf "\nInput image: $1"
	fi

	if [[ $ISSET_optipng -eq 1 ]]; then
		optimOptipng "$1"
	elif [[ $ISSET_pngcrush -eq 1 ]]; then
		optimPngcrush "$1"
	elif [[ $ISSET_pngout -eq 1 ]]; then
		optimPngout "$1"
	elif [[ $ISSET_advpng -eq 1 ]]; then
		optimAdvpng "$1"
	else
		echo "No PNG optimizer found"
		return 1
	fi
}

optimGIF() {
	if [ $DEBUG -eq 1 ]; then
		printf "\nInput image: $1"
	fi

	if [[ $ISSET_gifsicle -eq 1 ]]; then
		optimGifsicle "$1"
	else
		echo "No GIF optimizer found"
		return 1
	fi
}

readableSize() {
	local size=$1
	if ((size >= 1000000000)); then
		printf "%.1fGb" "$(echo "scale=1; $size/1024/1024/1024" | bc)"
	elif ((size >= 1000000)); then
		printf "%.1fMb" "$(echo "scale=1; $size/1024/1024" | bc)"
	else
		printf "%.1fKb" "$(echo "scale=1; $size/1024" | bc)"
	fi
}

readableTime() {
	local T=$1
	local D=$((T / 86400))
	local H=$(((T % 86400) / 3600))
	local M=$(((T % 3600) / 60))
	local S=$((T % 60))

	local result=""
	((D > 0)) && result+="$D days "
	((H > 0)) && result+="$H hours "
	((M > 0)) && result+="$M minutes "
	((D > 0 || H > 0 || M > 0)) && result+="and "
	printf "%s%d seconds\n" "$result" $S
}

findExclude() {
	if [ -n "$EXCLUDE_LIST" ]; then
		local pattern=${EXCLUDE_LIST//,/\\|}
		grep -v "$pattern"
	else
		grep -v ">>>>>>>>>>>>>"
	fi
}

checkEnabledExtensions() {
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

includeExtensions() {
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

joinBy() {
	local d=$1
	shift
	echo -n "$1"
	shift
	printf "%s" "${@/#/$d}"
}
lockDir() {
	if [ -f "${TMP_PATH}/${LOCK_FILE_NAME}" ]; then
		sed "/^$/d" "${TMP_PATH}/${LOCK_FILE_NAME}" >"${TMP_PATH}/${LOCK_FILE_NAME}.tmp" &&
			mv "${TMP_PATH}/${LOCK_FILE_NAME}.tmp" "${TMP_PATH}/${LOCK_FILE_NAME}"
		echo "$DIR_PATH" >>"${TMP_PATH}/${LOCK_FILE_NAME}"
	else
		echo "$DIR_PATH" >"${TMP_PATH}/${LOCK_FILE_NAME}"
	fi
}

unlockDir() {
	if [ -f "${TMP_PATH}/${LOCK_FILE_NAME}" ]; then
		sed "/^$/d" "${TMP_PATH}/${LOCK_FILE_NAME}" >"${TMP_PATH}/${LOCK_FILE_NAME}.tmp" &&
			mv "${TMP_PATH}/${LOCK_FILE_NAME}.tmp" "${TMP_PATH}/${LOCK_FILE_NAME}"
		if [[ $(wc -l "${TMP_PATH}/${LOCK_FILE_NAME}" | sed 's/^[\ ]*//' | cut -d ' ' -f1) -gt 1 ]]; then
			grep -v "^${DIR_PATH}$" "${TMP_PATH}/${LOCK_FILE_NAME}" >"${TMP_PATH}/${LOCK_FILE_NAME}.tmp" &&
				mv "${TMP_PATH}/${LOCK_FILE_NAME}.tmp" "${TMP_PATH}/${LOCK_FILE_NAME}"
		else
			rm "${TMP_PATH}/${LOCK_FILE_NAME}"
		fi
	fi
}

checkDirLock() {
	if [ -f "${TMP_PATH}/${LOCK_FILE_NAME}" ]; then
		sed "/^$/d" "${TMP_PATH}/${LOCK_FILE_NAME}" >"${TMP_PATH}/${LOCK_FILE_NAME}.tmp" &&
			mv "${TMP_PATH}/${LOCK_FILE_NAME}.tmp" "${TMP_PATH}/${LOCK_FILE_NAME}"
		if [[ $(grep "^${DIR_PATH}$" "${TMP_PATH}/${LOCK_FILE_NAME}") == "$DIR_PATH" ]]; then
			echo "The directory is already locked by another script run! Exiting..."
			echo
			exit 0
		fi
	fi
}

savePerms() {
	if [ -n "$1" ]; then
		PERMS_OWNER=$(stat -c %u "$1")
		PERMS_GROUP=$(stat -c %g "$1")
		PERMS_MOD=$(stat -c %a "$1")
	fi
}

restorePerms() {
	if [ -n "$PERMS_OWNER" ] && [ -n "$PERMS_GROUP" ] && [ -n "$PERMS_MOD" ]; then
		chown "$PERMS_OWNER:$PERMS_GROUP" "$1"
		chmod "$PERMS_MOD" "$1"
	fi
}
usage() {
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
	echo "    --resmush               Use resmush.it API to optimize images."
	echo "                            This option will override all other options."
	echo
	echo "    --resmush-quality=<quality>   Set quality for resmush.it service. Must be "
	echo "                            integer value from 0 to 100. Default value is "
	echo "                            92."
	echo
	echo "    --resmush-maxfilesize=<szie>   Set max filesize for resmush.it service. Must be "
	echo "                            integer value in bytes. Default value is "
	echo "                            5242880 (5Mb)."
	echo
	echo "    --resmush-preserve-exif    Preserve exif flag for resmush.it service. "
	echo "                            Default value is false."
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
CUR_USER=$(whoami)
SCRIPT_PATH="$(
	cd "$(dirname "$0")"
	pwd -P
)"
TIME_MARKER_PATH=""
TIME_MARKER_NAME=".timeMarker"
LOCK_FILE_NAME="zio.lock"
UNLOCK=0
if [ $CUR_USER == "root" ]; then
	SUDO=""
else
	SUDO="sudo"
fi

# System vars for reSmush.it
RESMUSH_ENABLED=0
RESMUSH_API_URL="http://api.resmush.it"
RESMUSH_QUALITY=92
RESMUSH_MAXFILESIZE=5242880 #5Mb
RESMUSH_PRESERVE_EXIF=false

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
while [ 1 ]; do
	if [ "${1#--path=}" != "$1" ]; then
		DIR_PATH="${1#--path=}"
	elif [ "$1" = "-p" ]; then
		shift
		DIR_PATH="$1"

	elif [ "${1#--time=}" != "$1" ]; then
		PERIOD="${1#--time=}"
	elif [ "$1" = "-t" ]; then
		shift
		PERIOD="$1"

	elif [ "${1#--time-marker=}" != "$1" ]; then
		TIME_MARKER="${1#--time-marker=}"
	elif [ "$1" = "-m" ]; then
		shift
		TIME_MARKER="$1"

	elif [ "${1#--tmp-path=}" != "$1" ]; then
		TMP_PATH="${1#--tmp-path=}"
	elif [ "$1" = "-tmp" ]; then
		shift
		TMP_PATH="$1"

	elif [ "${1#--exclude=}" != "$1" ]; then
		EXCLUDE_LIST="${1#--exclude=}"
	elif [ "$1" = "-e" ]; then
		shift
		EXCLUDE_LIST="$1"

	elif [ "${1#--extensions=}" != "$1" ]; then
		ENABLED_EXTENSIONS="${1#--extensions=}"
	elif [ "$1" = "-ext" ]; then
		shift
		ENABLED_EXTENSIONS="$1"

	elif [[ "$1" = "--help" || "$1" = "-h" ]]; then
		HELP=1

	elif [[ "$1" = "--version" || "$1" = "-v" ]]; then
		SHOW_VERSION=1

	elif [[ "$1" = "--quiet" || "$1" = "-q" ]]; then
		NO_ASK=1

	elif [[ "$1" = "--less" || "$1" = "-l" ]]; then
		LESS=1

	elif [[ "$1" = "--check-only" || "$1" = "-c" ]]; then
		CHECK_ONLY=1

	elif [[ "$1" = "--new-only" || "$1" = "-n" ]]; then
		NEW_ONLY=1

	elif [[ "$1" = "--debug" || "$1" = "-d" ]]; then
		DEBUG=1

	elif [[ "$1" = "--unlock" ]]; then
		UNLOCK=1

	elif [ "${1#--resmush-quality=}" != "$1" ]; then
		RESMUSH_QUALITY="${1#--resmush-quality=}"
		if ! [[ "$RESMUSH_QUALITY" =~ ^[0-9]+$ ]] || [ $RESMUSH_QUALITY -lt 0 ] || [ $RESMUSH_QUALITY -gt 100 ]; then
			echo
			$SETCOLOR_FAILURE
			echo "Resmush quality must be an integer between 0 and 100!"
			$SETCOLOR_NORMAL
			echo
			exit 1
		fi

	elif [ "${1#--resmush-maxfilesize=}" != "$1" ]; then
		RESMUSH_MAXFILESIZE="${1#--resmush-maxfilesize=}"
		if ! [[ "$RESMUSH_MAXFILESIZE" =~ ^[0-9]+$ ]]; then
			echo
			$SETCOLOR_FAILURE
			echo "Resmush maxfilesize must be a positive integer!"
			$SETCOLOR_NORMAL
			echo
			exit 1
		fi

	elif [ "$1" = "--resmush-preserve-exif" ]; then
		RESMUSH_PRESERVE_EXIF=true

	elif [ "$1" = "--resmush" ]; then
		RESMUSH_ENABLED=1

	elif [ -z "$1" ]; then
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
declare -A IMG_TYPES_ARR=(
	[JPG]="JPG"
	[PNG]="PNG"
	[GIF]="GIF"
)

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
declare -A TOOLS=(
	[JPG]="jpegoptim jpegtran djpeg cjpeg"
	[PNG]="pngcrush optipng pngout advpng"
	[GIF]="gifsicle"
)

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
FIND_EXT=""
if ! [ -z "${IMG_TYPES_ARR[JPG]}" ]; then
	FIND_EXT_ARR[JPG]='jpg jpeg jpe'
	FIND_EXT="${FIND_EXT} ${FIND_EXT_ARR[JPG]}"
fi
if ! [ -z "${IMG_TYPES_ARR[PNG]}" ]; then
	FIND_EXT_ARR[PNG]='png'
	FIND_EXT="${FIND_EXT} ${FIND_EXT_ARR[PNG]}"
fi
if ! [ -z "${IMG_TYPES_ARR[GIF]}" ]; then
	FIND_EXT_ARR[GIF]='gif'
	FIND_EXT="${FIND_EXT} ${FIND_EXT_ARR[GIF]}"
fi

# Trim leading/trailing spaces
FIND_EXT=$(echo "$FIND_EXT" | xargs)

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

# Generate names for find command using case-insensitive search
FIND_NAMES=""
for ext in $FIND_EXT; do
	if [ -z "$FIND_NAMES" ]; then
		FIND_NAMES="-iname *.${ext}"
	else
		FIND_NAMES="$FIND_NAMES -o -iname *.${ext}"
	fi
done

# Register OS-based dependencies
declare -A DEPS_DEBIAN_ARR
declare -A DEPS_REDHAT_ARR
declare -A DEPS_MACOS_ARR
DEPS_DEBIAN="wget autoconf automake libtool make bc jq curl"
DEPS_REDHAT="wget autoconf automake libtool make bc jq curl"
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

	# Add debug output
	if [ $DEBUG -eq 1 ]; then
		echo "Debug: Checking directory path: '$DIR_PATH'"
	fi

	checkParm "$DIR_PATH" "Path to files not set in -p(--path) option!"
	checkDir "$DIR_PATH"

	if [ $DEBUG -eq 1 ]; then
		echo "Debug: Changing to directory: '$DIR_PATH'"
	fi

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

for t in "${!TOOLS_ARRAY[@]}"; do

	FOUND=0
	echo -n ${TOOLS_ARRAY[$t]}"..."
	for p in "${!BINARY_PATHS_ARRAY[@]}"; do
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
		echo "1. Install dependencies"
		if [ $CHECK_ONLY -eq 0 ]; then
			echo "2. Continue without installing (default)"
		fi
		echo "0. Exit"
		echo
		echo -n "Enter selection [${CHECK_ONLY:-2}] > "

		read item
		case "$item" in
		1)
			echo
			echo "Select JPEG library to install:"
			echo "1. libjpeg (default)"
			echo "2. libjpeg-turbo (fastest)"
			echo "3. mozjpeg (smallest filesize, needs to compile from source)"
			echo
			echo -n "Enter selection [1] > "
			read jpeg_lib
			case "$jpeg_lib" in
			2)
				DEPS_DEBIAN=${DEPS_DEBIAN/libjpeg-progs/libjpeg-turbo-progs}
				DEPS_REDHAT=${DEPS_REDHAT/libjpeg*/libjpeg-turbo*}
				DEPS_MACOS=${DEPS_MACOS/libjpeg/jpeg-turbo}
				;;
			3)
				DEPS_DEBIAN=${DEPS_DEBIAN/libjpeg-progs/mozjpeg}
				DEPS_REDHAT=${DEPS_REDHAT/libjpeg*/mozjpeg}
				DEPS_MACOS=${DEPS_MACOS/libjpeg/mozjpeg}
				;;
			*)
				# Default libjpeg - no changes needed
				;;
			esac
			installDeps
			if [ $CHECK_ONLY -eq 1 ]; then
				echo "Exiting..."
				echo
				exit 0
			fi
			echo
			;;
		0)
			echo
			echo "Exiting..."
			echo
			exit 0
			;;
		2)
			if [ $CHECK_ONLY -eq 1 ]; then
				echo
				echo "Exiting..."
				echo
				exit 0
			fi
			echo
			;;
		*)
			if [ $CHECK_ONLY -eq 1 ]; then
				echo
				echo "Exiting..."
				echo
				exit 0
			fi
			echo
			;;
		esac
	else
		if [ $CHECK_ONLY -eq 1 ]; then
			installDeps
			echo "Exiting..."
			echo
			exit 0
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

# For debugging
if [ $DEBUG -eq 1 ]; then
	echo "Search pattern: $FIND_NAMES"
fi
# Find images
if [ -d "$DIR_PATH" ]; then
	# Save current directory
	ORIGINAL_DIR=$(pwd)

	# Get absolute path
	DIR_PATH=$(readlink -f "$DIR_PATH")

	# Verify directory exists after resolving path
	if [ ! -d "$DIR_PATH" ]; then
		echo "Directory not found after resolving path: $DIR_PATH"
		exit 1
	fi

	# Change to target directory
	if ! cd "$DIR_PATH" 2>/dev/null; then
		echo "Cannot access directory: $DIR_PATH"
		exit 1
	fi

	FULL_DIR_PATH=$(pwd)

	if [ $DEBUG -eq 1 ]; then
		echo "Debug: Current directory: $(pwd)"
		echo "Debug: FULL_DIR_PATH: $FULL_DIR_PATH"
	fi

	# Find images from current directory
	IMAGES=$(find . $FIND_INCLUDE \( $FIND_NAMES \) -print0 2>/dev/null | tr '\0' '\n')
	if [ ! -z "$EXCLUDE_LIST" ]; then
		IMAGES=$(echo "$IMAGES" | findExclude)
	fi

	# Return to original directory
	cd "$ORIGINAL_DIR" || exit 1
else
	echo "Directory not found: $DIR_PATH"
	exit 1
fi

# Num of images
IMAGES_TOTAL=$(echo "$IMAGES" | wc -l)

# If images found
if [ ! -z "$IMAGES" ]; then

	# Unlock
	if [[ $UNLOCK -eq 1 ]]; then
		unlockDir
	fi

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

	processImages "$IMAGES"

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
