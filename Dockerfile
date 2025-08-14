FROM debian:stable-20250811-slim AS fatcat-builder
ARG FATCAT_ARCHIVE_URL="https://github.com/Gregwar/fatcat/archive"
ARG FATCAT_VERSION=v1.1.0
ARG FATCAT_CHECKSUM="sha256:303efe2aa73cbfe6fbc5d8af346d0f2c70b3f996fc891e8859213a58b95ad88c"
ENV FATCAT_TARBALL="${FATCAT_VERSION}.tar.gz"
WORKDIR /fatcat
RUN apt-get update && \
  apt-get -y install \
  build-essential \
  cmake \
  wget \
  xz-utils \
  zlib1g-dev
ADD --checksum=${FATCAT_CHECKSUM} ${FATCAT_ARCHIVE_URL}/${FATCAT_TARBALL} .
RUN tar xvf "${FATCAT_TARBALL}" && \
  cmake fatcat-* -DCMAKE_CXX_FLAGS='-static' && \
  make -j$(nproc)

FROM debian:stable-20250811-slim AS dockerpi-vm
ARG RPI_KERNEL_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/archive/afe411f2c9b04730bcc6b2168cdc9adca224227c.zip"
ARG RPI_KERNEL_CHECKSUM="sha256:295a22f1cd49ab51b9e7192103ee7c917624b063cc5ca2e11434164638aad5f4"
ENV RPI_KERNEL="qemu-rpi-kernel"
ENV RPI_KERNEL_ZIP="${RPI_KERNEL}.zip"
VOLUME /sdcard
COPY --from=fatcat-builder /fatcat/fatcat /usr/local/bin/fatcat
COPY ./entrypoint.sh /entrypoint.sh
RUN apt-get update && \
  apt-get -y install \
  fdisk \
  qemu-system-aarch64 \
  qemu-system-arm \
  unzip \
  xz-utils && \
  rm -rf /var/lib/apt/lists/*
ADD --checksum=${RPI_KERNEL_CHECKSUM} ${RPI_KERNEL_URL} ${RPI_KERNEL_ZIP}
RUN unzip ${RPI_KERNEL_ZIP} && \
  mkdir -p /root/${RPI_KERNEL} && \
  mv ${RPI_KERNEL}-*/kernel-qemu-4.19.50-buster /root/${RPI_KERNEL}/ && \
  mv ${RPI_KERNEL}-*/versatile-pb.dtb /root/${RPI_KERNEL}/ && \
  rm -rf /tmp/* && \
  rm ${RPI_KERNEL_ZIP}
ENTRYPOINT ["bash", "./entrypoint.sh"]
