FROM debian:stable

ARG ARCH
# Need to pass arch argument to script
WORKDIR /
ADD ./build-image.sh .
ADD ./utils.sh .
ENV ARCH=${ARCH}
ENTRYPOINT /build-image.sh ${ARCH}