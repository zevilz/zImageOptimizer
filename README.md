# zImageOptimizer [![Version](https://img.shields.io/badge/version-v0.2.0-orange.svg)](https://github.com/zevilz/zImageOptimizer/releases/tag/0.2.0)

Simple bash script for lossless image optimize JPEG, PNG and GIF images in specified directory include subdirectories.

Tested only on Debian 9.2 amd64!

## Features
- lossless image optimization with small image size in output;
- script work recursively;
- checks optimization tools on start;
- option for automatic install dependences and optimization tools if one or more of it not found (supported deb-based linux distributions for now, like Debian 8+, Ubuntu 14.04+);
- readable information in output and total info after optimization;
- no limit for file size (limit only by hardware);
- no limit for number of files;
- no limit for length of file name (limit on by file system);
- supported special characters (except slashes and back slashes), spaces and not latin characters in file name.

## Tools
JPEG:
- jpegoptim
- jpegtran
- [MozJPEG](https://github.com/mozilla/mozjpeg.git)

PNG:
- pngcrush (v.1.7.22+)
- optipng
- [pngout](http://www.jonof.id.au/kenutils)
- advpng

GIF:
- gifsicle

One or more tools for each format required for optimization.

## Usage
```bash
bash zImageOptimizer.sh -p /path/to/files
```
or
```bash
bash zImageOptimizer.sh --path=/path/to/files
```

Supported parameters:
- -h, --help        - shows help
- -p, --path        - specify input directory without slash in the end of path
- -n, --no-ask      - execute script without any questions and users actions
- -c, --check-only  - check tools only with an opportunity to install dependences (all parameters will be ignored with this)

## Automatical installing dependences
Notice: curent user must be root ar user with sudo access.

Start script if you want to install dependences automatically. It check installed tools and print choise option dialog if one or more tools not found. Select option **Install dependences and exit** by typing appropriate number and press enter. Script install dependences based on your platform, distribution and package manager. After that restart script to recheck installed tools.

Supported only deb-based linux distributions for now:
- Debian 8+ and forks
- Ubuntu 14.04+ and forks

Tested on:
- Debian 9.2 amd64

If you have errors during installing dependences on supported platforms please contact me or open issue.

## Manual installing dependences
Notice: curent user must be root ar user with sudo access.

**Install following packages or analogs (for non deb-based distributions) from repositories**
```bash
jpegoptim libjpeg-turbo-progs pngcrush optipng advancecomp gifsicle autoconf automake libtool nasm make pkg-config git
```

**Install MozJPEG**
```bash
git clone https://github.com/mozilla/mozjpeg.git
cd mozjpeg/
autoreconf -fiv
./configure

# for make deb package and install
make deb
dpkg -i mozjpeg_*.deb

# for make rpm package and install
make rpm
rpm -i mozjpeg_*.rpm

# for install from sources
make
make install
```

**Install pngout**
```bash
wget http://static.jonof.id.au/dl/kenutils/pngout-20150319-linux.tar.gz
tar -xf pngout-20150319-linux.tar.gz
rm pngout-20150319-linux.tar.gz
cp pngout-20150319-linux/x86_64/pngout /bin/pngout
rm -rf pngout-20150319-linux
```

## Troubleshooting

**I'm install dependences but one of tool is marked as NOT FOUND**

By default script looks for binary files into folowing directories /bin/ /usr/bin/ /usr/local/bin/. If your binary file is not in these directories add your directory in variable BINARY_PATHS through a space like below and restart script
```bash
BINARY_PATHS="/bin/ /usr/bin/ /usr/local/bin/ /your/custom/path/"
```

**I have errors `djpeg: can't open /tmp/*` and `cjpeg: can't open /tmp/*` during optimization**

You have not write access to directory /tmp. Tools djpeg and cjpeg use this directory for temporary files. Change path in variable TMP_PATH on full path to directory which you have write access like below (directory must be exist)
```bash
TMP_PATH="/custom/path/to/temp/files/"
```

## TODO
- [x] ~~add parameter for execute script without any questions and users actions (for cron usage)~~
- [ ] add parameter for set time of the last change files for optimize only new images (for cron usage)
- [ ] add parameter for set quality for more small files in output
- [x] ~~add parameter for check tools only~~
- [x] ~~add support for optimize gif images~~
- [ ] add support for automatic install dependences on other platforms and distributions with other package managers
- [ ] add support for parallel optimization
- [ ] even more to improve results of compression

## Donations
Do you like script? Would you like to support its development? Feel free to donate

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.me/zevilz)

## Changelog
- 20.11.2017 - 0.2.0 - added [some features](https://github.com/zevilz/zImageOptimizer/releases/tag/0.2.0) and code refactoring
- 19.11.2017 - 0.1.1 - some bug fixes
- 19.11.2017 - 0.1.0 - beta released
