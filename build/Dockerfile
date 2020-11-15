FROM ubuntu
MAINTAINER Ben Ford <ben.ford@puppet.com>
WORKDIR /tmp
COPY load_syck.patch /tmp
RUN export DEBIAN_FRONTEND=noninteractive  \
        && apt-get update                                                                                                                  \
        && apt-get -y install build-essential ruby ruby-dev zlib1g-dev git cmake graphviz                                                  \
        && gem install syck sync json thin puppet-validator --no-doc                                                                       \
        && gem install puppet:3.8.7 puppet:4.8.2 puppet:4.10.12 puppet:5.5.22 puppet:6.19.1 --no-doc                                       \
        && find / -name syck_node_monkeypatch.rb | xargs -I% sh -c 'cd $(dirname %); patch -p0 < /tmp/load_syck.patch'                     \
        && find / -name monkey_patches.rb | xargs -I% sh -c "sed -i 's/DEFAULT_PARAMS\[:ciphers\] <</#DEFAULT_PARAMS\[:ciphers\] <</' %;"  \
        && apt-get -y purge build-essential cmake  ruby-dev zlib1g-dev                                                                     \
        && apt-get -y autoclean                                                                                                            \
        && apt-get -y autoremove                                                                                                           \
        && rm -rf `gem environment gemdir`/cache                                                                                           \
        && rm -rf /var/lib/apt/lists/*

CMD ["puppet-validator", "--graph"]
