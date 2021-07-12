FROM ubuntu:20.04 as build-env

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y git build-essential

RUN git clone --depth=1 --branch v2.3.3 https://github.com/apple/cups.git 

ADD patches/0001-reverse-label-orientation.patch cups/0001-reverse-label-orientation.patch

RUN cd cups && \
    git config --global user.name "Cloud Build" && \
    git config --global user.email "cloud-build@a1comms.com" && \
    git am 0001-reverse-label-orientation.patch

RUN cd cups && \
    ./configure && \
    make -j $(( $(nproc) + 1 ))

FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y cups psmisc

COPY --from=build-env cups/filter/rastertolabel /usr/lib/cups/filter/rastertolabel

RUN chown root:root /usr/lib/cups/filter/rastertolabel && \
    chmod 755 /usr/lib/cups/filter/rastertolabel

RUN /usr/sbin/cupsd && sleep 16 && \
    /usr/sbin/cupsctl --no-remote-admin --remote-any --share-printers && \
    /usr/sbin/lpadmin -p Zebra_LP2844 -E -v usb://Zebra/LP2844 -m drv:///sample.drv/zebraep2.ppd && \
    /usr/sbin/lpadmin -p Zebra_LP2844 -o orientation-requested-default=6 && \
    /usr/sbin/lpadmin -p Zebra_LP2844 -o Resolution=203dpi && \
    /usr/sbin/lpadmin -p Zebra_LP2844 -o Darkness=30 && \
    /usr/sbin/lpadmin -p Zebra_LP2844 -o PageSize=w288h432 && \
    killall -s TERM cupsd && sleep 30

EXPOSE 631

CMD ["/usr/sbin/cupsd", "-f"]