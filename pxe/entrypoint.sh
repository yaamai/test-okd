#!/usr/bin/env bash
set -e
set -x

cleanup() {
  ip addr del dev $interface $server_ip/$server_prefix_len || true
}

main() {
  local interface=${PXE_INTF:-br0}
  local server_ip=${PXE_IP:-10.101.101.1}
  local server_prefix_len=${PXE_IP_LEN:-24}
  local server_url=${PXE_URL:-http://$server_ip:8000}
  local subnet=${PXE_SUBNET:-10.101.101.100,10.101.101.150}

  trap cleanup EXIT

  ip addr add dev $interface $server_ip/$server_prefix_len || true
  ip link set dev $interface up || true

  sed 's$__SERVER__$'$server_url'$g' -i $PWD/tftpboot/pxelinux.cfg/*

  dnsmasq \
    -d \
    -R \
    -z \
    --no-hosts \
    --log-debug \
    --log-queries \
    -E \
    -i $interface \
    -F $subnet \
    --enable-tftp \
    --tftp-root=$PWD/tftpboot \
    --dhcp-hostsdir=/dnsmasq/hosts \
    --dhcp-leasefile=/dnsmasq/leases \
    --local=/local/ \
    --domain=local \
    --domain-needed \
    --conf-dir=/dnsmasq,*.conf \
    --dhcp-boot=/pxelinux.0 &

  cd $PWD/http && python3 -m http.server &

  wait -n
}

main
