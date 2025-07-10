#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "zeroconf",
#     "qrcode[pil]",
# ]
# ///

# Script taken from https://gist.github.com/benigumocom/a6a87fc1cb690c3c4e3a7642ebf2be6f

"""
Android11
Pair and connect devices for wireless debug on terminal

python-zeroconf: A pure python implementation of multicast DNS service discovery
https://github.com/jstasiak/python-zeroconf

qrcode: Pure python QR Code generator
https://github.com/lincolnloop/python-qrcode
"""

import subprocess
import qrcode
import signal
import sys
from zeroconf import ServiceBrowser, Zeroconf


TYPE = "_adb-tls-pairing._tcp.local."
NAME = "debug"
PASS = "123456"
FORMAT_QR = "WIFI:T:ADB;S:%s;P:%s;;"

CMD_PAIR = "adb pair %s:%s %s"
CMD_DEVICES = "adb devices -l"

class MyListener:
    def add_service(self, zeroconf, type, name):
        info = zeroconf.get_service_info(type, name)
        print("Service %s added." % name)
        print("service info: %s\n" % info)
        self.pair(info)

    def remove_service(self, zeroconf, type, name):
        print("Service %s removed." % name)
        print("Press enter to exit...\n")

    def update_service(self, zeroconf, type, name):
        """Handle service updates. Required by python-zeroconf."""
        info = zeroconf.get_service_info(type, name)
        print("Service %s updated." % name)
        print("service info: %s\n" % info)
        # Optionally handle updates - you can leave this empty if not needed
        pass

    def pair(self, info):
        cmd = CMD_PAIR % (info.server, info.port, PASS)
        print(cmd)
        try:
            subprocess.run(cmd, shell=True, check=False)
        except (KeyboardInterrupt, subprocess.SubprocessError) as e:
            print(f"Pairing interrupted: {e}")


def display_qr_code(text):
    """Generate and display a QR code in the terminal."""
    try:
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=1,
            border=1
        )
        qr.add_data(text)
        qr.make(fit=True)
        
        qr.print_ascii(invert=True)
    except Exception as e:
        print(f"Error generating QR code: {e}")
        print(f"QR code data: {text}")


def signal_handler(sig, frame):
    """Handle interrupt signals gracefully."""
    print("\n\nInterrupt received. Cleaning up...")
    sys.exit(0)


def main():
    # Set up signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    text = FORMAT_QR % (NAME, PASS)
    display_qr_code(text)

    print("Scan QR code to pair new devices.")
    print("[Developer options]-[Wireless debugging]-[Pair device with QR code]")
    print("Press Ctrl+C or Enter to exit...")

    zeroconf = None
    browser = None
    
    try:
        zeroconf = Zeroconf()
        listener = MyListener()
        browser = ServiceBrowser(zeroconf, TYPE, listener)
        input("Press enter to exit...\n\n")

    except KeyboardInterrupt:
        print("\nInterrupt received during setup. Exiting...")
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        # Clean up resources
        print("Cleaning up...")
        if browser:
            try:
                browser.cancel()
            except Exception as e:
                print(f"Error closing browser: {e}")
        
        if zeroconf:
            try:
                zeroconf.close()
            except Exception as e:
                print(f"Error closing zeroconf: {e}")
        
        # Show final device list
        try:
            print("Current ADB devices:")
            subprocess.run(CMD_DEVICES, shell=True, check=False)
        except Exception as e:
            print(f"Error listing devices: {e}")


if __name__ == '__main__':
    main()
