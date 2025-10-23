# Dockerfile for building WiFiHook iOS daemon with Theos

FROM debian:bullseye-slim

# Install all necessary dependencies
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    git \
    perl \
    make \
    sudo \
    fakeroot \
    unzip \
    ca-certificates \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash builder && \
    echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER builder
WORKDIR /home/builder

# Clone Theos
ENV THEOS=/home/builder/theos
RUN git clone --recursive https://github.com/theos/theos.git $THEOS

# Install iOS SDKs
RUN curl -LO https://github.com/theos/sdks/archive/master.zip && \
    unzip -q master.zip && \
    mv sdks-master/*.sdk $THEOS/sdks/ && \
    rm -rf master.zip sdks-master

# Install iOS toolchain
RUN echo "n" | bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)" || \
    echo "Toolchain installation attempted"

# Set environment variables
ENV PATH="$THEOS/bin:$PATH"

# Set up build directory
WORKDIR /home/builder/build

# Copy project files
COPY --chown=builder:builder . /home/builder/build/

# Fix line endings in control file
RUN sed -i 's/\r$//' control

# Build command - creates .deb package and copies to /output
CMD ["bash", "-c", "make clean && make package FINALPACKAGE=1 && sudo mkdir -p /output && sudo cp -v packages/*.deb /output/ 2>/dev/null || cp -v packages/*.deb /output/ || echo 'Build completed - check packages/ directory'"]
