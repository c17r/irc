FROM alpine:latest as builder

ENV BITLBEE_COMMIT 0b1448f
ENV DISCORD_COMMIT ba47eed
ENV FACEBOOK_COMMIT 553593d
ENV SLACK_COMMIT 39c7b5b

ENV STRIP true

RUN set -x \
	&& apk update \
	&& apk upgrade \
	&& apk add --no-cache autoconf gnutls-dev pidgin-dev libgcrypt-dev libwebp-dev automake build-base curl git json-glib-dev libtool python2 \
	&& rm -rf /var/cache/apk/*

RUN cd /root \
	&& git clone https://github.com/bitlbee/bitlbee \
	&& cd bitlbee \
	&& ./configure --purple=1 \
	&& make \
	&& cp bitlbee / \
	&& make install \
	&& make install-dev \
	&& make install-etc \
	&& if [ "$STRIP" == "true" ]; then strip /usr/local/sbin/bitlbee; fi

FROM builder as discord-builder
RUN cd /root \
	&& git clone https://github.com/sm00th/bitlbee-discord \
	&& cd bitlbee-discord \
	&& ./autogen.sh \
	&& ./configure \
	&& make \
	&& make install \
	&& if [ "$STRIP" == "true" ]; then strip /usr/local/lib/bitlbee/discord.so; fi

FROM builder as facebook-builder
RUN cd /root \
	&& git clone https://github.com/jgeboski/bitlbee-facebook \
	&& cd bitlbee-facebook \
	&& ./autogen.sh \
	&& make \
	&& make install \
	&& if [ "$STRIP" == "true" ]; then strip /usr/local/lib/bitlbee/facebook.so; fi

FROM builder as slack-builder
RUN cd /root \
	&& git clone https://github.com/dylex/slack-libpurple \
	&& cd slack-libpurple \
	&& make \
	&& mkdir -p /usr/share/pixmaps/pidgin/protocols/16/ \
	&& mkdir -p /usr/share/pixmaps/pidgin/protocols/22/ \
	&& mkdir -p /usr/share/pixmaps/pidgin/protocols/48/ \
	&& make install \
	&& if [ "$STRIP" == "true" ]; then strip /usr/lib/purple-2/libslack.so; fi

FROM alpine:latest

RUN apk update \
	&& apk upgrade \
	&& apk add --no-cache glib gnutls json-glib libgcrypt libpurple libpurple-bonjour libpurple-oscar libpurple-xmpp libwebp pidgin \
	&& apk add --no-cache znc znc-modperl znc-modpython znc-modtcl znc-extra \
	&& rm -rf /var/cache/apk/* \
	&& adduser -u 1000 -S irc \
	&& addgroup -g 1000 -S irc \
	&& mkdir -p /var/run/znc/znc/ \
	&& touch /var/run/znc/znc/pid \
	&& touch /var/run/bitlbee.pid \
	&& chown irc:irc /var/run/znc/znc/pid \
	&& chown irc:irc /var/run/bitlbee.pid \
	&& mkdir -p /var/lib/bitlbee \
	&& mkdir -p /var/lib/znc \
	&& chown -R irc:irc /var/lib/bitlbee \
	&& chown -R irc:irc /var/lib/znc

COPY entry.sh /entry.sh
COPY --from=builder /usr/local/etc/bitlbee/ /usr/local/etc/bitlbee/
COPY --from=builder /usr/local/include/bitlbee/ /usr/local/include/bitlbee/
COPY --from=builder /usr/local/lib/pkgconfig/bitlbee.pc /usr/local/lib/pkgconfig/bitlbee.pc
COPY --from=builder /usr/local/sbin/bitlbee /usr/local/sbin/bitlbee
COPY --from=builder /usr/local/share/bitlbee/help.txt /usr/local/share/bitlbee/help.txt

COPY --from=discord-builder /usr/local/lib/bitlbee/discord.* /usr/local/lib/bitlbee/
COPY --from=discord-builder /usr/local/share/bitlbee/discord-help.txt /usr/local/share/bitlbee/discord-help.txt

COPY --from=facebook-builder /usr/local/lib/bitlbee/facebook.* /usr/local/lib/bitlbee/

COPY --from=slack-builder /usr/lib/purple-2/libslack.so /usr/lib/purple-2/libslack.so
# COPY --from=slack-builder /usr/share/pixmaps/pidgin/protocols/16/slack.png /usr/share/pixmaps/pidgin/protocols/16/slack.png
# COPY --from=slack-builder /usr/share/pixmaps/pidgin/protocols/22/slack.png /usr/share/pixmaps/pidgin/protocols/22/slack.png
# COPY --from=slack-builder /usr/share/pixmaps/pidgin/protocols/48/slack.png /usr/share/pixmaps/pidgin/protocols/48/slack.png

USER irc
ENTRYPOINT ["/bin/sh", "/entry.sh"]
