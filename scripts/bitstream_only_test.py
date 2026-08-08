from pathlib import Path
from time import sleep
from pynq import Bitstream

BITSTREAM_PATH = "/home/xilinx/ForgeRV/forgerv.bit"
FPGA_MANAGER_STATE_PATH = Path(
    "/sys/class/fpga_manager/fpga0/state"
)

print("ForgeRV Bitstream-Only Test", flush=True)
print("---------------------------", flush=True)
print(f"Bitstream: {BITSTREAM_PATH}", flush=True)

if not Path(BITSTREAM_PATH).is_file():
    raise FileNotFoundError(
        f"Bitstream does not exist: {BITSTREAM_PATH}"
    )

print("Creating Bitstream object...", flush=True)

bitstream = Bitstream(BITSTREAM_PATH)

print("Bitstream object created", flush=True)
print("Programming FPGA...", flush=True)

bitstream.download()

print("Bitstream download returned", flush=True)

if FPGA_MANAGER_STATE_PATH.is_file():
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
else:
    print(
        "FPGA manager state file is unavailable",
        flush=True
    )

print(
    "No Overlay, hardware-description, GPIO, "
    "Block RAM, or MMIO access has occurred",
    flush=True
)

for elapsed_seconds in range(1, 11):
    sleep(1)

    print(
        f"System responsive after {elapsed_seconds} second(s)",
        flush=True
    )

print("PASS: bitstream-only test completed", flush=True)