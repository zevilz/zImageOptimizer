# Use phusion/baseimage as base image. To make your builds
# reproducible, make sure you lock down to a specific version, not
# to `latest`! See
# https://github.com/phusion/baseimage-docker/blob/master/Changelog.md
# for a list of version numbers.
FROM phusion/baseimage:0.11

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# ...put your own build instructions here...

RUN mkdir -p /work/

COPY * /work/

WORkDIR /work/

RUN chmod +x zImageOptimizer.sh

RUN echo 1 | ./zImageOptimizer.sh -c
# RUN ["/bin/bash /work/zImageOptimizer.sh -c"]

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

CMD ["./zImageOptimizer.sh","-p","/work/images","-t","15d"]
