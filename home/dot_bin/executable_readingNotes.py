#!/usr/bin/env python3
from __future__ import absolute_import, division, print_function

import dbus, subprocess, os


class BaseInfo:
    """ Base class for reader info. """
    name = None
    pid = None
    bus_name = None
    bus_name_format = ''
    bus_name_format_list = ['name', 'pid']
    object_path = None
    proxy = None
    file_path = None
    current_page = None
    number_of_pages = None

    def __init__(self, pid=None):
        self.pid = pid
        self.bus_name = self.get_bus_name()
        self.proxy = dbus.SessionBus().get_object(self.bus_name,
                                                  self.object_path)

    def get_bus_name(self):
        """ Get bus name from bus_name_format or search it manually. """
        format_list = [getattr(self, i) for i in self.bus_name_format_list]
        if self.bus_name_format and all(format_list):
            return self.bus_name_format.format(*format_list)
        else:
            proxy = dbus.SessionBus().get_object('org.freedesktop.DBus',
                                                 '/org/freedesktop/DBus')
            buses = [
                i
                for i in proxy.ListNames(dbus_interface='org.freedesktop.DBus')
                if i.startswith(self.name)
            ]
            if len(buses) == 1:
                return buses[0]
            else:
                print('No unique bus name found')
                exit(1)


class ZathuraInfo(BaseInfo):
    """ Class for zathura info """
    name = 'org.pwmt.zathura'
    object_path = '/org/pwmt/zathura'
    interface_name = name
    properties = {}
    bus_name_format = '{}.PID-{}'

    def __init__(self, pid=None):
        super().__init__(pid=pid)
        self.properties = self.get_properties()
        attributes = {
            'number_of_pages': 'numberofpages',
            'file_path': 'filename',
            'current_page': 'pagenumber',
        }
        if self.properties:
            for item in attributes:
                if item == 'current_page':
                    # The number of current page is not right.
                    page = self.properties.get(attributes[item]) + 1
                    self.__setattr__(item, page)
                else:
                    self.__setattr__(item,
                                     self.properties.get(attributes[item]))

    def get_properties(self):
        iface = dbus.Interface(self.proxy, 'org.freedesktop.DBus.Properties')
        return iface.GetAll(self.interface_name)


class OkularInfo(BaseInfo):
    """ Class for okular info. """
    name = 'org.kde.okular'
    object_path = '/okular'
    interface_name = name
    bus_name_format = '{}-{}'

    def __init__(self, pid=None):
        super().__init__(pid=pid)
        attributes = {
            'number_of_pages': 'pages',
            'file_path': 'currentDocument',
            'current_page': 'currentPage',
        }
        iface = dbus.Interface(self.proxy, self.interface_name)
        # self.iface = dbus.Interface(self.proxy, self.interface_name)
        for item in attributes:
            value = iface.get_dbus_method(attributes[item])()
            self.__setattr__(item, (value))


def main():
    command = ("xprop -id $(xprop -root 32x '\t$0' _NET_ACTIVE_WINDOW" +
               " | cut -f 2) | grep -E '_NET_WM_PID|WM_CLASS'")
    # command = "xprop -id 0x2600005 | grep -E '_NET_WM_PID|WM_CLASS'"
    output = subprocess.check_output(command, shell=True).decode().split('\n')
    pid = [i for i in output if i.startswith('_NET_WM_PID')][0].split('=')[1]
    pid = pid.strip()
    wm_class = [i for i in output if i.startswith('WM_CLASS')][0].split('=')[1]
    class_dict = {'zathura': ZathuraInfo, 'okular': OkularInfo}
    for program in class_dict:
        if program in wm_class.lower():
            reader_info = class_dict[program](pid=pid)
            command_to_run = ['orgProtocol.py', '-t', 'r']
            args = {}
            args['url'] = "file:" + reader_info.file_path
            args['title'] = os.path.basename(reader_info.file_path)
            args['title'] = os.path.splitext(args['title'])[0]
            args['body'] = reader_info.current_page
            for arg in args.items():
                arg = [str(i) for i in arg]
                command_to_run = command_to_run + arg
            subprocess.run(command_to_run)


if __name__ == '__main__':
    main()
