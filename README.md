# zImageOptimizer

Simple lossless image optimizer for JPEG and PNG images in specified directory include subdirectories.

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
for jpeg:
- jpegoptim
- jpegtran
- [MozJPEG](https://github.com/mozilla/mozjpeg.git)

for png:
- pngcrush (v.1.7.22+)
- optipng
- [pngout](http://www.jonof.id.au/kenutils)
- advpng

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
- -h, --help - shows help
- -p, --path - specify input directory without slash in the end of path

## Manual installing dependences
**Install following packages or analogs (for non deb-based distributions) from repositories**
```bash
jpegoptim libjpeg-turbo-progs pngcrush optipng advancecomp autoconf automake libtool nasm make pkg-config git
```

**Install MozJPEG**
```bash
apt-get install autoconf automake libtool nasm make pkg-config git
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
make install
```

**Install pngout**
```bash
wget http://static.jonof.id.au/dl/kenutils/pngout-20150319-linux.tar.gz &&\
tar -xf pngout-20150319-linux.tar.gz &&\
rm pngout-20150319-linux.tar.gz &&\
cp pngout-20150319-linux/x86_64/pngout /bin/pngout &&\
rm -rf pngout-20150319-linux
```

## TODO
- add parameter for execute script without any questions and users actions (for cron usage)
- add parameter for set time of the last change files for optimize only new images (for cron usage)
- add parameter for set quality for more small files in output
- add parameter for check tools only
- add support for optimize gif images
- add support for automatic install dependences on other platforms and distributions with other package managers
- even more to improve results of compression

## Donations
Do you like script? Would you like to support its development? Feel free to donate

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.me/zevilz)

## Troubleshooting

**I'm install dependences but one of tool is marked as NOT FOUND**

By default script looks for binary files into folowing directories /bin/ /usr/bin/ /usr/local/bin/. If your binary file is not in these directories add your directory in variable BINARY_PATHS through a space like below and restart script
```bash
BINARY_PATHS="/bin/ /usr/bin/ /usr/local/bin/ /your/custom/path/"
```

## Changelog
- 19.11.2017 - 0.1.0 - beta released
