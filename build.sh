#!/usr/bin/env bash
set -e

# ==============================================================================
# CONFIGURATION - Tùy chỉnh Board & Shield ở đây khi copy sang repo mới
# ==============================================================================
BOARD="seeeduino_xiao_ble"
SHIELD="pmw3610_xiao rgbled_adapter"
SNIPPET="studio-rpc-usb-uart"            # Để trống nếu không dùng snippet (vd: "")
EXTRA_CMAKE_ARGS="-DCONFIG_ZMK_STUDIO=y" # Các cờ cmake bổ sung (để trống nếu không dùng)
OUTPUT_NAME="pmw3610_xiao"               # Tên file xuất ra: <OUTPUT_NAME>.uf2
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="/home/ubuntu/zmk-workspace"
OUTPUT_DIR="${SCRIPT_DIR}/output"
VENV_DIR="/home/ubuntu/.zmk-venv"
SDK_DIR="/home/ubuntu/zephyr-sdk"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

export ZEPHYR_SDK_INSTALL_DIR="${SDK_DIR}"
if [ -f "${VENV_DIR}/bin/activate" ]; then
    source "${VENV_DIR}/bin/activate"
fi

mkdir -p "${OUTPUT_DIR}"

build_firmware() {
    local pristine_arg=""
    if [ "$1" == "pristine" ]; then
        pristine_arg="-p always"
        echo -e "${YELLOW}==> Pristine build (xóa cache, build sạch từ đầu)...${NC}"
    fi

    echo -e "${BLUE}==> Building ZMK Firmware: Board=[${BOARD}], Shield=[${SHIELD}]...${NC}"
    cd "${WORKSPACE_DIR}"

    local snippet_arg=""
    if [ -n "${SNIPPET}" ]; then
        snippet_arg="-S ${SNIPPET}"
    fi

    local extra_args=()
    if [ -n "${EXTRA_CMAKE_ARGS}" ]; then
        extra_args+=(${EXTRA_CMAKE_ARGS})
    fi

    west build ${pristine_arg} -s zmk/app -d "build/${OUTPUT_NAME}" -b "${BOARD}" ${snippet_arg} -- \
        -DZMK_CONFIG="${SCRIPT_DIR}/config" \
        -DSHIELD="${SHIELD}" \
        -DZMK_EXTRA_MODULES="${SCRIPT_DIR}" \
        "${extra_args[@]}"

    cp "build/${OUTPUT_NAME}/zephyr/zmk.uf2" "${OUTPUT_DIR}/${OUTPUT_NAME}.uf2"
    echo -e "${GREEN}==> Build SUCCESS: ${OUTPUT_DIR}/${OUTPUT_NAME}.uf2${NC}"
}

build_reset() {
    echo -e "${BLUE}==> Building Settings Reset Firmware for [${BOARD}]...${NC}"
    cd "${WORKSPACE_DIR}"
    west build -s zmk/app -d "build/settings_reset" -b "${BOARD}" -- \
        -DZMK_CONFIG="${SCRIPT_DIR}/config" \
        -DSHIELD="settings_reset"

    cp "build/settings_reset/zephyr/zmk.uf2" "${OUTPUT_DIR}/settings_reset.uf2"
    echo -e "${GREEN}==> Build SUCCESS: ${OUTPUT_DIR}/settings_reset.uf2${NC}"
}

clean_build() {
    echo -e "${YELLOW}Cleaning build directories...${NC}"
    rm -rf "${WORKSPACE_DIR}/build/${OUTPUT_NAME}"
    rm -rf "${WORKSPACE_DIR}/build/settings_reset"
    rm -rf "${OUTPUT_DIR}"/*
    echo -e "${GREEN}Clean completed.${NC}"
}

case "$1" in
    reset)
        build_reset
        ;;
    all)
        build_firmware
        build_reset
        ;;
    clean)
        clean_build
        ;;
    pristine)
        build_firmware "pristine"
        ;;
    *)
        build_firmware
        ;;
esac

echo -e "${GREEN}===================================================${NC}"
echo -e "${GREEN}Output firmware files in: ${OUTPUT_DIR}${NC}"
ls -lh "${OUTPUT_DIR}"
echo -e "${GREEN}===================================================${NC}"