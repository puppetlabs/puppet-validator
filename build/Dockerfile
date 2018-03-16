FROM gliderlabs/alpine
MAINTAINER Ben Ford <ben.ford@puppet.com>
WORKDIR /tmp
COPY load_syck.patch /tmp
RUN apk add --no-cache ruby ruby-dev zlib-dev build-base git cmake graphviz                                    \
        && gem install syck json puppet-validator --no-ri --no-rdoc                                            \
        && gem install puppet:3.8.7 puppet:4.7.1 puppet:4.8.2 puppet:4.10.10 puppet:5.4.0 --no-ri --no-rdoc    \
        && apk del --purge binutils-libs binutils isl libgomp libatomic mpfr3 mpc1 gcc make musl-dev libc-dev  \
        && apk del --purge fortify-headers g++ build-base libattr libacl libbz2 xz-libs libarchive cmake       \
        && apk del --purge gmp-dev ruby-dev zlib-dev                                                           \
        && rm -rf `gem environment gemdir`/cache                                                               \
        && find / -name syck_node_monkeypatch.rb | xargs -I% sh -c 'cd $(dirname %); patch -p0 < /tmp/load_syck.patch'

CMD ["puppet-validator", "--graph"]
