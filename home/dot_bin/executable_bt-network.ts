#!/usr/bin/env -S deno run --allow-read --allow-write --allow-env --allow-sys --unstable-detect-cjs

import process from "node:process";
import * as dbus from "npm:@homebridge/dbus-native";
import { Command } from "npm:commander";

const BLUEZ_SERVICE = "org.bluez";
const OBJECT_MANAGER_IFACE = "org.freedesktop.DBus.ObjectManager";
const ADAPTER_IFACE = "org.bluez.Adapter1";
const DEVICE_IFACE = "org.bluez.Device1";
const NETWORK_IFACE = "org.bluez.Network1";
const NETWORK_SERVER_IFACE = "org.bluez.NetworkServer1";
const PROPERTIES_IFACE = "org.freedesktop.DBus.Properties";

const program = new Command();

program
  .name("bt-network")
  .description("A Bluetooth network manager")
  .version("1.0.0")
  .option("-a, --adapter <name|mac>", "Adapter Name or MAC");

async function getManagedObjects(bus: any): Promise<any> {
  return new Promise((resolve, reject) => {
    const service = bus.getService(BLUEZ_SERVICE);
    service.getInterface("/", OBJECT_MANAGER_IFACE, (err: any, iface: any) => {
      if (err) return reject(err);
      iface.GetManagedObjects((err: any, objects: any) => {
        if (err) return reject(err);
        resolve(objects);
      });
    });
  });
}

function getProperty(props: any[][], name: string): any {
  for (const [propName, propValue] of props) {
    if (propName === name) return propValue[1][0];
  }
  return undefined;
}

async function findAdapter(
  bus: any,
  adapterNameOrMac?: string,
): Promise<string> {
  const objects: any = await getManagedObjects(bus);
  for (const [path, interfaces] of objects) {
    for (const [ifaceName, props] of interfaces) {
      if (ifaceName === ADAPTER_IFACE) {
        const name = getProperty(props, "Name");
        const address = getProperty(props, "Address");
        if (
          !adapterNameOrMac || name === adapterNameOrMac ||
          address === adapterNameOrMac
        ) {
          return path;
        }
      }
    }
  }
  throw new Error("Adapter not found");
}

async function findDevice(
  bus: any,
  adapterPath: string,
  deviceNameOrMac: string,
): Promise<string> {
  const objects: any = await getManagedObjects(bus);
  for (const [path, interfaces] of objects) {
    if (!path.startsWith(adapterPath)) continue;
    for (const [ifaceName, props] of interfaces) {
      if (ifaceName === DEVICE_IFACE) {
        const name = getProperty(props, "Name");
        const alias = getProperty(props, "Alias");
        const address = getProperty(props, "Address");
        if (
          name === deviceNameOrMac || alias === deviceNameOrMac ||
          address === deviceNameOrMac
        ) {
          return path;
        }
      }
    }
  }
  throw new Error("Device not found");
}

async function isConnected(propIface: any): Promise<boolean> {
  return new Promise((resolve) => {
    propIface.Get(NETWORK_IFACE, "Connected", (err: any, connected: any) => {
      if (err) return resolve(false);
      resolve(connected[1][0]);
    });
  });
}

program
  .command("client <device> <profile>")
  .alias("c")
  .description("Connect to a network device (profile: gn, panu, nap)")
  .option(
    "-d, --daemon",
    "Run in background (returns immediately after connection)",
  )
  .action(async (deviceNameOrMac, profile, cmdOptions) => {
    const bus = dbus.systemBus();
    const globalOptions = program.opts();
    try {
      const adapterPath = await findAdapter(bus, globalOptions.adapter);
      const devicePath = await findDevice(bus, adapterPath, deviceNameOrMac);
      const service = bus.getService(BLUEZ_SERVICE);

      const propIface = await new Promise<any>((resolve, reject) => {
        service.getInterface(
          devicePath,
          PROPERTIES_IFACE,
          (err: any, iface: any) => {
            if (err) {
              return reject(
                new Error(`Failed to get properties interface: ${err}`),
              );
            }
            resolve(iface);
          },
        );
      });

      if (await isConnected(propIface)) {
        console.log("Network service is already connected");
        if (cmdOptions.daemon) process.exit(0);
      } else {
        service.getInterface(
          devicePath,
          NETWORK_IFACE,
          (err: any, networkIface: any) => {
            if (err) {
              console.error("Network service is not supported by this device");
              process.exit(1);
            }

            networkIface.Connect(profile, (err: any, interfaceName: string) => {
              if (err) {
                if (
                  err.name === "org.bluez.Error.Failed" &&
                  err.message[0] === "Operation already in progress"
                ) {
                  console.log("Connection is already in progress...");
                } else {
                  console.error("Connect error:", err);
                  process.exit(1);
                }
              } else {
                console.log(`Connected to interface: ${interfaceName}`);
                if (cmdOptions.daemon) process.exit(0);
              }
            });
          },
        );
      }

      if (!cmdOptions.daemon) {
        propIface.on("PropertiesChanged", (iface: string, changed: any) => {
          if (iface === NETWORK_IFACE && changed.Connected) {
            const connected = changed.Connected[1];
            console.log(
              `Network service is ${connected ? "connected" : "disconnected"}`,
            );
            if (!connected) process.exit(0);
          }
        });

        const onSignal = () => {
          console.log("\nReceived signal, disconnecting...");
          service.getInterface(
            devicePath,
            NETWORK_IFACE,
            (err: any, networkIface: any) => {
              if (err) process.exit(0);
              networkIface.Disconnect((err: any) => {
                if (err) console.error("Disconnect error:", err);
                process.exit(0);
              });
            },
          );
        };

        process.on("SIGINT", onSignal);
        process.on("SIGTERM", onSignal);
      }
    } catch (err: any) {
      console.error("Error:", err.message);
      process.exit(1);
    }
  });

program
  .command("server <profile> <bridge>")
  .alias("s")
  .description("Start a network server (profile: gn, panu, nap)")
  .option("-d, --daemon", "Run in background (as daemon)")
  .action(async (profile, bridge, cmdOptions) => {
    const bus = dbus.systemBus();
    const globalOptions = program.opts();
    try {
      const adapterPath = await findAdapter(bus, globalOptions.adapter);
      const service = bus.getService(BLUEZ_SERVICE);

      service.getInterface(
        adapterPath,
        NETWORK_SERVER_IFACE,
        (err: any, serverIface: any) => {
          if (err) {
            console.error("Network server is not supported by this adapter");
            process.exit(1);
          }

          serverIface.Register(profile, bridge, (err: any) => {
            if (err) {
              console.error("Register error:", err);
              process.exit(1);
            }
            console.log(`${profile.toUpperCase()} server registered`);
            if (cmdOptions.daemon) process.exit(0);
          });

          if (!cmdOptions.daemon) {
            const unregister = () => {
              serverIface.Unregister(profile, (err: any) => {
                if (err) console.error("Unregister error:", err);
                console.log(`${profile.toUpperCase()} server unregistered`);
                process.exit(0);
              });
            };

            process.on("SIGINT", unregister);
            process.on("SIGTERM", unregister);
          }
        },
      );
    } catch (err: any) {
      console.error("Error:", err.message);
      process.exit(1);
    }
  });

program
  .command("disconnect <device>")
  .alias("d")
  .description("Disconnect from a network device")
  .action(async (deviceNameOrMac) => {
    const bus = dbus.systemBus();
    const globalOptions = program.opts();
    try {
      const adapterPath = await findAdapter(bus, globalOptions.adapter);
      const devicePath = await findDevice(bus, adapterPath, deviceNameOrMac);
      const service = bus.getService(BLUEZ_SERVICE);

      service.getInterface(
        devicePath,
        NETWORK_IFACE,
        (err: any, networkIface: any) => {
          if (err) {
            console.error("Network service is not supported by this device");
            process.exit(1);
          }

          networkIface.Disconnect((err: any) => {
            if (err) {
              console.error("Disconnect error:", err);
              process.exit(1);
            }
            console.log("Successfully disconnected");
            process.exit(0);
          });
        },
      );
    } catch (err: any) {
      console.error("Error:", err.message);
      process.exit(1);
    }
  });

program
  .command("list")
  .alias("l")
  .description("List all connected network devices")
  .action(async () => {
    const bus = dbus.systemBus();
    try {
      const objects = await getManagedObjects(bus);
      let found = false;
      for (const [path, interfaces] of objects) {
        let isConnectedNetwork = false;
        for (const [ifaceName, props] of interfaces) {
          if (ifaceName === NETWORK_IFACE) {
            if (getProperty(props, "Connected") === true) {
              isConnectedNetwork = true;
              break;
            }
          }
        }

        if (isConnectedNetwork) {
          found = true;
          let name, address;
          for (const [ifaceName, props] of interfaces) {
            if (ifaceName === DEVICE_IFACE) {
              name = getProperty(props, "Name") || getProperty(props, "Alias");
              address = getProperty(props, "Address");
            }
          }
          console.log(
            `${address || "Unknown"} (${name || "Unknown"}) - ${path}`,
          );
        }
      }
      if (!found) {
        console.log("No connected network devices found");
      }
      process.exit(0);
    } catch (err: any) {
      console.error("Error:", err.message);
      process.exit(1);
    }
  });

if (Deno.args.length === 0) {
  program.help();
}

program.parse(Deno.args, { from: "user" });
