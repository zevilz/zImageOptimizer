# zImageOptimizer [![Version](https://img.shields.io/badge/version-v0.9.6-orange.svg)](https://github.com/zevilz/zImageOptimizer/releases/tag/0.9.6) [![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.me/zevilz)

Simple bash script for lossless image optimizing JPEG, PNG and GIF images in a specified directory include subdirectories on Linux, MacOS and FreeBSD.

## Features
- lossless image optimization with a small image size in the output;
- works recursively;
- checks optimization tools after the start;
- option for automatic install dependences and optimization tools if one or more of it is not found (see supported distributions [here](https://github.com/zevilz/zImageOptimizer#automatical-installing-dependences));
- readable output info and total info after optimization;
- no limit for a file size (limited only by hardware);
- no limit for a number of files;
- no limit for a length of a filename (limited only by a file system);
- supports for special characters (except slashes and back slashes), spaces, not latin characters in a filename;
- supports for search of images changed in a certain period of time;
- supports for use of the special time marker for search only new files (based on last modify time).
- supports extensions via special hooks

## Requirements
- bash 4+

## Tools
JPEG:
- [jpegoptim](http://www.kokkonen.net/tjko/projects.html)
- jpegtran, djpeg and cjpeg (from [libjpeg library](http://www.ijg.org/))

PNG:
- [pngcrush](http://pmt.sourceforge.net/pngcrush/) (v1.7.22+)
- [optipng](http://optipng.sourceforge.net/) (v0.7+)
- [pngout](http://www.jonof.id.au/kenutils)
- advpng (from [AdvanceCOMP library](http://www.advancemame.it/comp-readme.html))

GIF:
- [gifsicle](http://www.lcdf.org/gifsicle/)

One or more tools required for optimization. djpeg/cjpeg does not support CMYK colorspace and does not participate in the optimization of such images.

Notice: Optimization via djpeg/cjpeg is currently temporarily disabled to prevent an increase in size of output files in lossless mode. Later, djpeg/cjpeg options for lossless compression and small output file size will be selected.

## Usage

### Usual usage
```bash
bash zImageOptimizer.sh -p /path/to/files
```
or
```bash
bash zImageOptimizer.sh --path=/path/to/files
```

Supported options:
- -h (--help) - shows a help message;
- -v (--version) - shows a script version;
- -p (--path) - specify a full path to the input directory (usage: `-p <dir> | --path=<dir>`);
- -q (--quiet) - executes the script without any questions and users actions;
- -l (--less) - don't shows the optimizing process;
- -c (--check-only) - checks tools with an opportunity to install dependences;
- -t (--time) - sets the period for which to look for files by last modified time (usage: `-t <period> | --time=<period>`);
- -n (--new-only) - use the time marker file for looking new images only;
- -m (--time-marker) - sets the custom full path or the custom filename of a time marker file (usage: `-m <name|path> | --time-marker=<name|path>`);
- -tmp (--tmp-path) - sets the custom directory full path for temporary files (usage: `-tmp <dir> | --tmp-path=<dir>`);
- -e (--exclude) - a comma separated parts list of paths to files for an exclusion from search (the script removes from the search files in the full path of which includes any value from the list; usage: `-e <list> | --exclude=<list>`);
- -ext (--extensions) - a comma separated list of script's extensions to enable. Script's extensions disabled by default. Use `all` to enable all found extensions (usage: `-ext <list> | --extensions=<list> | -ext all | --extensions=all`).

Notices:
- you may combine options;
- -h(--help) option ignore all other options;
- -v(--version) option ignore all other options (except for -h(--help));
- -c(--check-only) option ignore all other options (except for -h(--help) and -v(--version));
- a path in -p(--path) and -tmp(--tmp-path) options may be with and without a slash in the end of the path;
- it is impossible to use together -t(--time) and -n(--new-only) options;
- you must use -m(--time-marker) option with -n(--new-only) option.

Recommendation: use [GNU Screen](https://en.wikipedia.org/wiki/GNU_Screen) or analogs if there are many images in an input directory, because the optimization may can take long time.

After starting optimization, the script creates special temporary lock file (`/tmp/zio.lock` by default), where path to working directory is added. After optimization is finished, the script deletes this file (or deletes current path to working directory from the file with several parallel optimizations). This is done to prevent cycling optimization and avoid conflicts during optimization for longer than period between optimizations. Notice: if the script is terminated abnormally, you should delete lock file manually.

### Excluding folders/files from search
```bash
bash zImageOptimizer.sh -p /path/to/files -e <list>
```

Example:
```bash
bash zImageOptimizer.sh -p /path/to/files -e /var/www/test.com,backup,uploads/orig.png
```

### Usage with set the period
```bash
bash zImageOptimizer.sh -p /path/to/files -t <period>
```

Supported periods:
- minutes (10m, 30m etc.),
- hours (1h, 10h etc.),
- days (1d, 30d  etc.).

Example:
```bash
bash zImageOptimizer.sh -p /path/to/files -t 15d
```

### Usage with the time marker (recommended for a cron usage)
```bash
bash zImageOptimizer.sh -p /path/to/files -n
```

Notice: by default the time marker file created in working a directory which set in -p(--path) option with a filename **.timeMarker**.

#### Custom time marker name
Use -m(--time-marker) option and set a new filename if you want to change the time marker filename:
```bash
bash zImageOptimizer.sh -p /path/to/files -n -m myCustomMarkerName
```
Path to time marker will be `/path/to/files/myCustomMarkerName`

#### Custom time marker path and name
Use -m(--time-marker) option and set a new path and filename if you want to change the time marker path:
```bash
bash zImageOptimizer.sh -p /path/to/files -n -m /path/to/marker/directory/markerName
```
Path to the time marker will be `/path/to/marker/directory/markerName`

#### Cron usage
Using default time marker:
```bash
0 0 * * * /bin/bash zImageOptimizer.sh -p /first/directory -q -n
0 1 * * * /bin/bash zImageOptimizer.sh -p /second/directory -q -n
```

Using custom time marker path and filename:
```bash
0 0 * * * /bin/bash zImageOptimizer.sh -p /first/directory -q -n -m /path/to/first/marker/firstMarkerName
0 1 * * * /bin/bash zImageOptimizer.sh -p /second/directory -q -n -m /path/to/second/marker/secondMarkerName
```

Also you may collect all markers in own directory:
```bash
0 0 * * * /bin/bash zImageOptimizer.sh -p /first/directory -q -n -m /path/to/markers/directory/firstMarkerName
0 1 * * * /bin/bash zImageOptimizer.sh -p /second/directory -q -n -m /path/to/markers/directory/secondMarkerName
```

Notice: use -l(--less) option if you want exclude optimizing process in cron email messages

#### Manually create/modify the time marker file
You may manually create the time marker file or change it last modified time:
```bash
touch -m /path/to/marker/markerName
```

If you want to create the marker with specify time or change marker last modified time with specify time:
```bash
touch -t [[CC]YY]MMDDhhmm[.SS]
```
where:
- CC – 2 first digits of the year,
- YY – 2 last digits of the year,
- MM – month,
- DD – date,
- hh – hours in 24 format,
- mm – minutes,
- SS – seconds.

Example:
```bash
touch -t 201712041426.00 /path/to/marker/markerName
```

### Usage with custom path to the temporary files directory
```bash
bash zImageOptimizer.sh -p /path/to/files -tmp /custom/path/to/temporary/directory
```

## Docker

Docker image provided by [Varun Batra](https://github.com/VarunBatraIT).

If you have built the docker container then dependencies are installed already. To use docker either start with mounting to /work/images folder which is compressed every 15 days for example:

```bash
docker run -u "$UID:$GID" --volume /path/to/images:/work/images -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro  varunbatrait/zimageoptimizer
```

Or you can come up with your own CMD for example:

```bash
# mkdir /mnt/ImagesHundred/marker
docker run -it -u "$UID:$GID" -d --volume /mnt/ImagesHundred/marker:/work/marker --volume /mnt/ImagesHundred/images/:/work/images/ -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro varunbatrait/zimageoptimizer ./zImageOptimizer.sh -p /work/images/ -q -n -m /work/marker/marker
```

## Automatical installing dependences
Notice: curent user must be root or user with sudo access.

Start the script in the optimization mode (-p|--path) or the checking tools mode (-c|--check-only, recommended) if you want to install dependences automatically. It will check installed tools and printing a choise option dialog if one or more tools not found. Select **Install dependences and exit** option by typing a appropriate number and press enter. The script will install dependences based on your platform, distribution and package manager. You may need to enter a password and confirm actions during installation dependences. Restart script to recheck installed tools after that.

Supported on:
- DEB-based linux distributions (i686/amd64)
  - Debian 7+
  - Ubuntu 14.04+
- RPM-based linux distributions (i686/x86_64)
  - RHEL 6+
  - CentOS 6+
  - Fedora 24+
- FreeBSD 10+ (i686/amd64)
- MacOS 10.10+

Tested on:
- DEB-based linux distributions
  - Debian 7.11 i686 minimal
  - Debian 8.9 i686 minimal
  - Debian 9.2 amd64
  - Ubuntu 14.04.5 amd64
  - Ubuntu 16.04.3 amd64
  - Ubuntu 18.04.2 amd64
- RPM-based linux distributions
  - RHEL 6.9 i686 minimal
  - RHEL 7.4 x86_64 server
  - CentOS 6.9 x86_64 minimal
  - CentOS 7.4.1708 x86_64 minimal
  - Fedora 24 i686 minimal
  - Fedora 25 x86_64 minimal
  - Fedora 26 x86_64 minimal
  - Fedora 27 x86_64 workstation
  - Fedora 30 beta x86_64 server (required `initscripts` package)
- FreeBSD (in some cases it may be necessary to run auto-install twice)
  - 10.3 i686
  - 11.1 amd64
  - 11.2 amd64
  - 12.0 amd64
- MacOS
  - 10.10
  - 10.11.6
  - 10.13.6

If you have errors during installing dependences on supported platforms please contact me or open issue.

## Manual installing dependences
Notice: curent user must be root or user with sudo access.

**Install following packages from repositories/ports**

DEB-based:
```bash
apt-get install jpegoptim libjpeg-progs pngcrush optipng advancecomp gifsicle wget autoconf automake libtool make bc -y
```

RHEL:
```bash
yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E '%{rhel}').noarch.rpm -y
subscription-manager repos --enable rhel-$(rpm -E '%{rhel}')-server-optional-rpms
yum install jpegoptim libjpeg* pngcrush optipng advancecomp gifsicle wget autoconf automake libtool make bc -y
```

CentOS:
```bash
yum install epel-release -y
yum install jpegoptim libjpeg* pngcrush optipng advancecomp gifsicle wget autoconf automake libtool make bc -y
```

Fedora:
```bash
dnf install epel-release -y
dnf install jpegoptim libjpeg* pngcrush optipng advancecomp gifsicle wget autoconf automake libtool make bc -y
```

MacOS:

Install homebrew if not installed
```bash
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

Install packages via homebrew
```bash
brew install jpegoptim libjpeg pngcrush optipng advancecomp gifsicle jonof/kenutils/pngout
```

Install new bash version (default 3.* version not supported) via homebrew
```bash
brew install bash
```

Add path to new bash version in `/private/etc/shells`
```bash
/usr/local/bin/bash
```

Add alias to new bash version in `~/.bash_profile`
```bash
alias bash="/usr/local/bin/bash"
```

Logout and login again for enable new alias or add permanent alias for curent session
```bash
alias bash="/usr/local/bin/bash"
```

FreeBSD:

Install following ports
```bash
wget (/usr/ports/ftp/wget)
jpegoptim (/usr/ports/graphics/jpegoptim)
jpeg (/usr/ports/graphics/jpeg)
pngcrush (/usr/ports/graphics/pngcrush)
optipng (/usr/ports/graphics/optipng)
advancecomp (/usr/ports/archivers/advancecomp)
gifsicle (/usr/ports/graphics/gifsicle)
```

**Install pngout**

Linux:
```bash
wget http://static.jonof.id.au/dl/kenutils/pngout-20150319-linux.tar.gz
tar -xf pngout-20150319-linux.tar.gz
rm pngout-20150319-linux.tar.gz
cp pngout-20150319-linux/i686/pngout /bin/pngout     # for i686 arch
cp pngout-20150319-linux/x86_64/pngout /bin/pngout   # for x86_64/amd64 arch
rm -rf pngout-20150319-linux
```

FreeBSD:
```bash
wget http://static.jonof.id.au/dl/kenutils/pngout-20150319-bsd.tar.gz
tar -xf pngout-20150319-bsd.tar.gz
rm pngout-20150319-bsd.tar.gz
cp pngout-20150319-bsd/i686/pngout /bin/pngout    # for i686 arch
cp pngout-20150319-bsd/amd64/pngout /bin/pngout   # for amd64 arch
rm -rf pngout-20150319-bsd
```

**Install pngcrush (RHEL/CentOS 6.*)**
```bash
wget https://downloads.sourceforge.net/project/pmt/pngcrush/old-versions/1.8/1.8.0/pngcrush-1.8.0.tar.gz
tar -zxvf pngcrush-1.8.0.tar.gz
rm pngcrush-1.8.0.tar.gz
cd pngcrush-1.8.0
make
cp pngcrush /bin/
cd ../
rm -rf pngcrush-1.8.0
```

**Install advpng (RHEL/CentOS 6.*)**
```bash
yum install zlib-devel gcc-c++ -y
wget https://github.com/amadvance/advancecomp/releases/download/v2.0/advancecomp-2.0.tar.gz
tar -zxvf advancecomp-2.0.tar.gz
rm advancecomp-2.0.tar.gz
cd advancecomp-2.0
./configure
make
make install
cd ../
rm -rf advancecomp-2.0
```

## Extensions
Guide for extensions comming soon...

## Troubleshooting

**I'm install dependences but one of tool is marked as NOT FOUND**

By default the script looks for binary files into folowing directories /bin /usr/bin /usr/local/bin. If your binary file is not in these directories add your directory in variable BINARY_PATHS through a space like below and restart the script
```bash
BINARY_PATHS="/bin /usr/bin /usr/local/bin /your/custom/path"
```

**I have errors `djpeg: can't open /tmp/*` and `cjpeg: can't open /tmp/*` during optimization**

You have not write access to the directory /tmp. Tools djpeg and cjpeg use this directory for temporary files. Use -tmp(--tmp-path) option for set custom path.

**I run the script but have error `The directory is already locked by another script run! Exiting...`**

The script is already running in specified directory. If not, previous run of the script was not completed correctly. Delete lock file (`/tmp/zio.lock` by default) manually and repeat.

## TODO
- [x] ~~add option for execute the script without any questions and users actions (for cron usage)~~
- [x] ~~add option for set time of the last change files for optimize only new images (for cron usage)~~
- [ ] add an option for set quality for more small files in the output
- [x] ~~add an option for check tools only~~
- [x] ~~add support for optimize gif images~~
- [x] ~~add support for automatic install dependences on other platforms and distributions with other package managers~~
- [ ] add support for automatic install dependences on others linux distributions
- [ ] add support for parallel optimization
- [ ] even more to improve results of compression
- [ ] add SVG support
- [ ] add WebP support
- [ ] add logging
- [ ] add Ansible playbook
- [x] ~~add progrees indicator~~
- [x] ~~add extensions support~~
- [x] ~~add lock file to prevent cyclical optimization with long image optimization~~
- [ ] add repository for debian/ubuntu
- [ ] add repository for rhel/centos/fedora

## Contacts
- telegram [@zevilz](https://t.me/zevilz) (EN|RU)
- telegram chat [@zImageOptimizer](https://t.me/zImageOptimizer) (RU)

## Reviews
- [sysadmin.pm](https://sysadmin.pm/zimageoptimizer/) (RU)
- [glashkoff.com](https://glashkoff.com/blog/manual/kak-optimizirovat-izobrazheniya-sayta/) (RU)

## Donations
Do you like the script? Would you like to support its development? Feel free to donate

[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.me/zevilz)

## Changelog
- 20.04.2019 - 0.9.6 - added support for extensions, added lock file and [more](https://github.com/zevilz/zImageOptimizer/releases/tag/0.9.6)
- 06.02.2019 - 0.9.5 - fixed quality in cjpeg/djpeg compression
- 28.10.2018 - 0.9.4 - [added check for empty temporary file after decompress images with djpeg](https://github.com/zevilz/zImageOptimizer/releases/tag/0.9.4)
- 11.03.2018 - 0.9.3 - added a restoration of original files if their size is less or equal than optimized files size
- 27.02.2018 - 0.9.2 - fixed PNG file permissions if the script does not work from files owner
- 27.02.2018 - 0.9.1 - [added new features](https://github.com/zevilz/zImageOptimizer/releases/tag/0.9.1) and bugfixes
- 25.02.2018 - 0.9.0 - added support for working the script on MacOS 10.10+ with automatic install dependences
- 24.02.2018 - 0.8.1 - [added new parameter, updated info after optimizing, small fixes and small code refactoring](https://github.com/zevilz/zImageOptimizer/releases/tag/0.8.1)
- 04.12.2017 - 0.8.0 - [new features, bugfixes and code refactoring](https://github.com/zevilz/zImageOptimizer/releases/tag/0.8.0)
- 30.11.2017 - 0.7.0 - added support for working the script on FreeBSD with automatic install dependences, [bug fixes and more](https://github.com/zevilz/zImageOptimizer/releases/tag/0.7.0)
- 28.11.2017 - 0.6.0 - added support for automatic install dependences on RHEL 6+ and Fedora 24+
- 25.11.2017 - 0.5.0 - bug fixes and code refactoring
- 25.11.2017 - 0.4.0 - added support for automatic install dependences on Debian 7.* and some bugfixes
- 23.11.2017 - 0.3.0 - added support for automatic install dependences on CentOS 6.*
- 22.11.2017 - 0.2.3 - some bug fixes
- 21.11.2017 - 0.2.2 - added support for automatic install dependences on CentOS 7.*
- 20.11.2017 - 0.2.1 - some bug fixes
- 20.11.2017 - 0.2.0 - added [some features](https://github.com/zevilz/zImageOptimizer/releases/tag/0.2.0) and code refactoring
- 19.11.2017 - 0.1.1 - some bug fixes
- 19.11.2017 - 0.1.0 - beta released
