-- ####################################################
-- Copyright (C) 2017 DeadSix27
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ###################################################
-- its nothing, yet.
local mp = require 'mp'
local options = require 'mp.options'

function on_pause_change(name, value) print("pause") end
function on_file_loaded(event)
    print("++++INFO++++")
    print(mp.get_property_osd("video-codec"))
    print(mp.get_property_osd("hwdec-current"))
    print("----INFO----")
end
mp.observe_property("pause", "bool", on_pause_change)
mp.register_event("file-loaded", on_file_loaded)
