ARG ARCH
FROM jsc32-base:$ARCH-raw

LABEL description="Minimal Debian image to reproduce JSC dev"
LABEL maintainer="Paulo Matos <pmatos@igalia.com>"
 
CMD ["/bin/bash"]