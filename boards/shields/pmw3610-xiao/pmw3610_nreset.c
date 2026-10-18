/*
 * PMW3610 NRESET controller
 *
 * Vì ZMK sleep trên nRF52840 là System Off (cold boot khi wakeup),
 * module này chạy trong SYS_INIT ở priority THẤP HƠN sensor driver.
 * Mỗi lần boot/wakeup, NRESET bị pulse LOW→HIGH để force PMW3610
 * thoát khỏi REST mode và chạy power-up sequence sạch.
 *
 * Kết nối phần cứng:
 *   XIAO GPIO pin → NRESET của PMW3610
 *   (NRESET là active-low, kéo xuống GND để reset)
 */

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/init.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(pmw3610_nreset, LOG_LEVEL_INF);

/* Lấy GPIO spec từ node "nreset_pin" được alias qua "pmw3610-nreset" trong DTS overlay.
 * gpio-leds binding: child node chứa property "gpios"
 * DT_NODELABEL(nreset_pin) → trỏ đến child node có label "nreset_pin"
 *
 * GPIO_ACTIVE_LOW → gpio_pin_set_dt(..., 1) = pin LOW = RESET ACTIVE
 *                   gpio_pin_set_dt(..., 0) = pin HIGH = NORMAL OPERATION
 */
static const struct gpio_dt_spec nreset =
    GPIO_DT_SPEC_GET(DT_NODELABEL(nreset_pin), gpios);

static int pmw3610_nreset_init(void)
{
    if (!gpio_is_ready_dt(&nreset)) {
        LOG_ERR("PMW3610 NRESET GPIO không sẵn sàng");
        return -ENODEV;
    }

    /* Cấu hình pin là OUTPUT, mặc định INACTIVE (tức pin HIGH = không reset) */
    int ret = gpio_pin_configure_dt(&nreset, GPIO_OUTPUT_INACTIVE);
    if (ret < 0) {
        LOG_ERR("Không thể cấu hình NRESET GPIO: %d", ret);
        return ret;
    }

    /* Đảm bảo pin đang HIGH trước khi reset */
    gpio_pin_set_dt(&nreset, 0); /* INACTIVE = HIGH */
    k_busy_wait(1000);           /* 1ms ổn định */

    /* Pulse NRESET: kéo LOW tối thiểu 10µs (dùng 10ms cho chắc) */
    LOG_INF("PMW3610: Đang pulse NRESET...");
    gpio_pin_set_dt(&nreset, 1); /* ACTIVE = LOW → RESET */
    k_busy_wait(10000);          /* 10ms */
    gpio_pin_set_dt(&nreset, 0); /* INACTIVE = HIGH → kết thúc reset */

    /*
     * Chờ PMW3610 chạy internal power-up sequence:
     * - Sensor cần tối thiểu 150µs sau NRESET↑ trước khi nhận SPI
     * - Dùng 50ms để đảm bảo an toàn trước khi driver init
     */
    k_busy_wait(50000); /* 50ms */

    LOG_INF("PMW3610: NRESET hoàn tất, sensor sẵn sàng nhận init");
    return 0;
}

/*
 * POST_KERNEL priority 85:
 * - GPIO driver init ở priority ~40-50 → đã sẵn sàng
 * - SPI driver init ở priority ~90
 * - Sensor (PMW3610) init ở priority ~90-95 (CONFIG_SENSOR_INIT_PRIORITY)
 * Ta cần chạy SAU GPIO init nhưng TRƯỚC sensor init → priority 85 là đúng
 */
SYS_INIT(pmw3610_nreset_init, POST_KERNEL, 85);
