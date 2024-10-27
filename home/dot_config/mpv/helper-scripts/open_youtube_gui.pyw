#!/usr/bin/env python3
#- * -coding: utf - 8 - * -

# ####################################################
# Copyright (C) 2017 DeadSix27
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ###################################################


# very simple Tk UI to open youtube urls.


import tkinter as tk
import os
from subprocess import Popen
class ytdl(tk.Tk):
	def __init__(self):
		tk.Tk.__init__(self)
		self.entry = tk.Entry(self,width=50)
		self.wm_title("mpv YouTube")
		self.iconbitmap('mpv_file_icon.ico')
		self.label = tk.Label(self, text="Youtube URL:")
		self.button = tk.Button(self, text="Open", command=self.on_button)
		self.label.pack()
		self.entry.pack()
		self.button.pack()

	def on_button(self):
		url = self.entry.get()
		if not "youtu" in url:
			pass
		else:
			Popen(["mpv.exe","ytdl://{0}".format(url)],shell=True)
			exit(0)

w = ytdl()
w.mainloop()