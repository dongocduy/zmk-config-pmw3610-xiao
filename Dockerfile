FROM ghcr.io/skubmdi/docker-zmk-builder:main

WORKDIR /workspace
COPY config/west.yml /workspace/config/west.yml
RUN west init -l config && west update && west zephyr-export
