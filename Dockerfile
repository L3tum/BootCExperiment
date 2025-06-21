FROM quay.io/fedora/fedora-bootc:43

ARG TS_AUTHOR_KEY

ADD cockpit-serve.service /etc/systemd/system/cockpit-serve.service
ADD network-opt.sh /usr/local/bin/network-opt.sh
ADD network-opt.service /etc/systemd/system/network-opt.service
ADD tailscale-up.service /etc/systemd/system/tailscale-up.service

# bootupd currently does not support Raspberry Pi-specific firmware and bootloader files.
# This shim script copies the firmware and bootloader files to the correct location before
# calling the original bootupctl script.
# This is a temporary workaround until https://github.com/coreos/bootupd/issues/651 is resolved.
RUN dnf install -y bcm2711-firmware uboot-images-armv8 \
  	&& cp -P /usr/share/uboot/rpi_arm64/u-boot.bin /boot/efi/rpi-u-boot.bin \
  	&& mkdir -p /usr/lib/bootc-raspi-firmwares \
  	&& cp -a /boot/efi/. /usr/lib/bootc-raspi-firmwares/ \
  	&& dnf remove -y bcm2711-firmware uboot-images-armv8 \
  	&& mkdir /usr/bin/bootupctl-orig \
  	&& mv /usr/bin/bootupctl /usr/bin/bootupctl-orig/

COPY bootupctl-shim /usr/bin/bootupctl

# Install Cockpit and more
RUN dnf -y install cockpit cockpit-ws cockpit-podman git vim-enhanced tree \
    && systemctl enable cockpit.socket \
    && systemctl enable cockpit-serve.service

# Install tailscale and start it
RUN sed -i 's/AUTHOR_KEY/${TS_AUTHOR_KEY}/g' /etc/systemd/system/tailscale-up.service \
  	&& dnf -y install 'dnf5-command(config-manager)' \
    && dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo \
	&& dnf -y install tailscale \
	&& systemctl enable tailscaled \
    && systemctl enable tailscale-up.service

RUN dnf clean all

# Optimize Tailscale https://web.archive.org/web/20250312064023/https://www.reddit.com/r/Fedora/comments/1h2s38i/beginners_guide_to_install_and_optimize_tailscale/
RUN echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-tailscale.conf \
    && echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.d/99-tailscale.conf \
    && systemctl enable network-opt.service


