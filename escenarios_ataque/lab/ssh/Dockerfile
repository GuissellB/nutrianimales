FROM alpine:3.21
RUN apk add --no-cache openssh-server openssh-client sshpass \
    && mkdir -p /run/sshd /var/log/persona5
COPY sshd_config /etc/ssh/sshd_config
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY ataque_controlado.sh /usr/local/bin/ataque_controlado.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh /usr/local/bin/ataque_controlado.sh
EXPOSE 2222
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
