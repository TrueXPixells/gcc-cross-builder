ARG BASE_IMAGE=ubuntu:latest
FROM $BASE_IMAGE

RUN mkdir /elf-tools
COPY ./build.sh /elf-tools/build.sh
RUN apt-get update && apt-get install -y \
    git \
    wget \
    sudo \
    make \
    lsb-release \
  && chmod +x /elf-tools/build.sh \
  && /elf-tools/build.sh env \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /opt/mxe/.ccache \
  && rm -rf /opt/mxe/pkg

ENTRYPOINT ["/elf-tools/build.sh"]