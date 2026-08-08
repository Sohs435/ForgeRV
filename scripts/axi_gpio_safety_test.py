from pathlib import Path
from time import sleep
from pynq import MMIO

GPIO_BASE_ADDRESS = 0x41200000
GPIO_ADDRESS_RANGE = 0x1000

GPIO_CHANNEL_1_DATA = 0x00
GPIO_CHANNEL_1_DIRECTION = 0x04
GPIO_CHANNEL_2_DATA = 0x08
GPIO_CHANNEL_2_DIRECTION = 0x0C

FPGA_MANAGER_STATE_PATH = Path(
    "/sys/class/fpga_manager/fpga0/state"
)

print("ForgeRV AXI GPIO Safety Test", flush=True)
print("----------------------------", flush=True)
print(
    f"AXI GPIO base address: "
    f"0x{GPIO_BASE_ADDRESS:08X}",
    flush=True
)

if not FPGA_MANAGER_STATE_PATH.is_file():
    raise RuntimeError(
        "FPGA manager state file is unavailable"
    )

fpga_manager_state = (
    FPGA_MANAGER_STATE_PATH
    .read_text()
    .strip()
)

print(
    f"FPGA manager state: {fpga_manager_state}",
    flush=True
)

if fpga_manager_state != "operating":
    raise RuntimeError(
        f"FPGA manager is not operating: "
        f"{fpga_manager_state}"
    )

print("Creating AXI GPIO MMIO mapping...", flush=True)

gpio = MMIO(
    GPIO_BASE_ADDRESS,
    GPIO_ADDRESS_RANGE
)

print("AXI GPIO MMIO mapping created", flush=True)

try:
    print(
        "Writing zero to control channel...",
        flush=True
    )

    gpio.write(
        GPIO_CHANNEL_1_DATA,
        0x00000000
    ) # bit 0 = software reset asserted, bit 1 = core disabled

    print(
        "Control-channel write completed",
        flush=True
    )

    print(
        "Configuring channel 1 as outputs...",
        flush=True
    )

    gpio.write(
        GPIO_CHANNEL_1_DIRECTION,
        0x00000000
    ) # zero means every channel 1 bit is configured as an output

    print(
        "Channel 1 direction write completed",
        flush=True
    )

    print(
        "Configuring channel 2 as inputs...",
        flush=True
    )

    gpio.write(
        GPIO_CHANNEL_2_DIRECTION,
        0xFFFFFFFF
    ) # one means every channel 2 bit is configured as an input

    print(
        "Channel 2 direction write completed",
        flush=True
    )

    print(
        "Reading control channel...",
        flush=True
    )

    observed_control = gpio.read(
        GPIO_CHANNEL_1_DATA
    )

    print(
        f"Observed control value: "
        f"0x{observed_control:08X}",
        flush=True
    )

    if (observed_control & 0x1F) != 0:
        raise RuntimeError(
            "Control readback is not zero; "
            "the core may not be safely held in reset"
        )

    print(
        "PASS: processor is held in reset "
        "and remains disabled",
        flush=True
    )

    print(
        "Testing status selector while reset remains asserted...",
        flush=True
    )

    for status_select in range(8):
        control_value = status_select << 2
        # bit 0 remains zero -> software reset stays asserted
        # bit 1 remains zero -> core stays disabled
        # bits 4:2 select one of the eight status words

        print(
            f"Selecting status word {status_select}...",
            flush=True
        )

        gpio.write(
            GPIO_CHANNEL_1_DATA,
            control_value
        )

        observed_control = gpio.read(
            GPIO_CHANNEL_1_DATA
        )

        if (observed_control & 0x1F) != control_value:
            raise RuntimeError(
                f"Control readback failed for status selector "
                f"{status_select}: expected "
                f"0x{control_value:08X}, observed "
                f"0x{observed_control:08X}"
            )

        print(
            f"Reading status word {status_select}...",
            flush=True
        )

        status_value = gpio.read(
            GPIO_CHANNEL_2_DATA
        )

        print(
            f"Status word {status_select}: "
            f"0x{status_value:08X}",
            flush=True
        )

        sleep(0.1)

    print(
        "Restoring control value to zero...",
        flush=True
    )

    gpio.write(
        GPIO_CHANNEL_1_DATA,
        0x00000000
    )

    print(
        "PASS: AXI GPIO control and status paths are responsive",
        flush=True
    )

finally:
    print(
        "Ensuring processor remains in reset...",
        flush=True
    )

    gpio.write(
        GPIO_CHANNEL_1_DATA,
        0x00000000
    )

    print(
        "Final control value written: 0x00000000",
        flush=True
    )

print("AXI GPIO safety test completed", flush=True)
print(
    "Instruction Block RAM was not accessed",
    flush=True
)