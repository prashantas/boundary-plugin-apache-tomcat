-- Copyright 2015 Boundary, Inc.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local framework = require('framework')
local Plugin = framework.Plugin
local WebRequestDataSource = framework.WebRequestDataSource
local round = framework.util.round
local auth = framework.util.auth
local isHttpSuccess = framework.util.isHttpSuccess
local megaBytesToBytes = framework.util.megaBytesToBytes
local percentage = framework.util.percentage
local compose = framework.functional.compose
local notEmpty = framework.string.notEmpty

local function parseMetric(data, pattern)
  local val = data:match(pattern)
  return tonumber(round(val, 2))
end

local parsePercentage = compose(parseMetric, percentage)
local parseBytes = compose(parseMetric, megaBytesToBytes)

local function parse(data)
  local vals = {}

  vals['TOMCAT_JVM_FREE_MEMORY'] = parseBytes(data, 'Free memory: (%d+%.%d+) MB')
  vals['TOMCAT_JVM_TOTAL_MEMORY'] = parseBytes(data, 'Total memory: (%d+%.%d+) MB')
  vals['TOMCAT_HTTP_CURRENT_THREAD_COUNT'] = parseMetric(data, 'Current thread count: (%d+)')
  vals['TOMCAT_HTTP_CURRENT_THREAD_BUSY'] = parseMetric(data, 'Current thread busy: (%d+)')
  vals['TOMCAT_HTTP_MAX_PROCESSING_TIME'] = parseMetric(data, 'Max processing time: (%d+) ms')
  vals['TOMCAT_HTTP_REQUEST_COUNT'] = parseMetric(data, 'Request count: (%d+)')
  vals['TOMCAT_HTTP_ERROR_COUNT'] = parseMetric(data, 'Error count: (%d+)')
  vals['TOMCAT_HTTP_BYTES_SENT'] = parseBytes(data, 'Bytes sent: (%d+%.%d+) MB')
  vals['TOMCAT_HTTP_BYTES_RECEIVED'] = parseBytes(data, 'Bytes received: (%d+%.%d+) MB')
  vals['TOMCAT_MEMPOOL_HEAP_CMS_OLD_GEN'] = parsePercentage(data, 'CMS Old Gen</td><td>Heap memory</td><td>%d+%.%d+ MB</td><td>%d+%.%d+ MB</td><td>%d+%.%d+ MB</td><td>%d+%.%d+ MB %((%d+)%%%)</td>')
  vals['TOMCAT_MEMPOOL_HEAP_EDEN_SPACE'] = parsePercentage(data, 'Eden Space</td><td>Heap memory</td><td>%d+%.%d+ MB</td><td>%d+%.%d+ MB</td><td>%d+%.%d+ MB</td><td>%d+%.%d+ MB %((%d+)%%%)</td>')
  vals['TOMCAT_MEMPOOL_HEAP_SURVIVOR_SPACE'] = parsePercentage(data, 'Survivor Space</td><td>Heap memory</td><td>%d+%.%d+ MB</td><td>%d+%.%d+ MB</td><td>%d+%.%d+ MB</td><td>%d+%.%d+ MB %((%d+)%%%)</td>')
  vals['TOMCAT_MEMPOOL_NONHEAP_CMS_PERM_GEN'] = parsePercentage(data, 'CMS Perm Gen</td><td>Non%-heap memory</td><td>%d+%.%d+ MB</td><td>%d+%.%d+ MB</td><td>%d+%.%d+ MB</td><td>%d+%.%d+ MB %((%d+)%%%)</td>')
  vals['TOMCAT_MEMPOOL_NONHEAP_CODE_CACHE'] = parsePercentage(data, 'Code Cache</td><td>Non%-heap memory</td><td>%d+%.%d+ MB</td><td>%d+%.%d+ MB</td><td>%d+%.%d+ MB</td><td>%d+%.%d+ MB %((%d+)%%%)</td>')

  return vals
end

local params = framework.params

local options = {}
options.host = notEmpty(params.host, '127.0.0.1')
options.port = notEmpty(params.port, 80)
options.path = params.path
options.source = params.source
options.auth = auth(params.username, params.password)

local data_source = WebRequestDataSource:new(options)
local plugin = Plugin:new(params, data_source)
function plugin:onParseValues(data, extra)
  if not isHttpSuccess(extra.status_code) then
    self:emitEvent('error', plugin.source .. ' HTTP Error - ' .. extra.status_code, plugin.source, plugin.source, 'HTTP status code ' .. extra.status_code) 
    return
  end

  local vals = parse(data)
  return vals
end

plugin:run()

