#!/usr/bin/env lua5.1

local irc = require 'irc'
local sleep = require 'socket'.sleep
local seawolf = require 'seawolf'.__build 'variable'

local _, vault = pcall(require, 'vault')
local s = irc.new(vault.irc)

s:hook('OnChat', function(user, channel, message)
  print(('[%s] %s: %s'):format(channel, user.nick, message))
  local success, err = pcall(function ()
    _G.user = user
    _G.channel = channel
    _G.message = message
    _G.irc = s
    dofile 'interactive.lua'
  end)
  if not success then
    seawolf.variable.print_r(err)
  end
end)

s:connect(vault.server)

for _, chan in pairs(vault.channels) do
  s:join(chan)
end

while true do
  s:think()
  sleep(0.5)
end
