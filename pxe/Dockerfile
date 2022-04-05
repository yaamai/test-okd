FROM alpine as images
RUN apk add --update curl
RUN mkdir -p /work/ && cd /work &&\
    curl -LO https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/35.20220313.3.1/x86_64/fedora-coreos-35.20220313.3.1-live-kernel-x86_64 &&\
    curl -LO https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/35.20220313.3.1/x86_64/fedora-coreos-35.20220313.3.1-live-initramfs.x86_64.img &&\
    curl -LO https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/35.20220313.3.1/x86_64/fedora-coreos-35.20220313.3.1-live-rootfs.x86_64.img

FROM alpine
RUN mkdir -p /pxe /pxe/tftpboot/pxelinux.cfg /pxe/http &&\
    apk add --update dnsmasq python3 bash openssh-client syslinux curl
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static /tini
RUN chmod +x /tini
COPY --from=images /work/ /pxe/http/
ENTRYPOINT ["/tini", "--", "/entrypoint.sh"]

WORKDIR /pxe
RUN cp /usr/share/syslinux/*c32 /pxe/tftpboot && cp /usr/share/syslinux/pxelinux.0 /pxe/tftpboot

COPY default /pxe/tftpboot/pxelinux.cfg
COPY entrypoint.sh /

# 
# COPY --from=builder /work/tftpboot /pxe/tftpboot
# COPY --from=builder /work/http /pxe/http
# 
# DEFAULT pxeboot
# TIMEOUT 20
# PROMPT 0
# LABEL pxeboot
#     KERNEL http://<HTTP_server>/rhcos-<version>-live-kernel-<architecture> 
#     APPEND initrd=http://<HTTP_server>/rhcos-<version>-live-initramfs.<architecture>.img coreos.live.rootfs_url=http://<HTTP_server>/rhcos-<version>-live-rootfs.<architecture>.img coreos.inst.install_dev=/dev/sda coreos.inst.ignition_url=http://<HTTP_server>/bootstrap.ign
