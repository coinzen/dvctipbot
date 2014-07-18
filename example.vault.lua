--[[
  This file is for storage of sensitive information ONLY.
]]

local m = {
  -- Connection settings
  server = {
    host = 'chat.freenode.net',
    port = 6667,
  },
  irc = {
    nick = 'dvctipbot',
    username = 'registered-user-name',
    password = 'password',
    verbose = true,
  },
  channels = {
    '#devcoin',
    '#ophal',
  },
  devcoin = {
    server = 'node hostname or IP',
    use_ssl = true,
    user = 'rpc user',
    password = 'rpc pass',
    port = '8332', -- The default devcoind json-rpc port is 62332, but 8332 might work
  },

  -- Users granted to send tips
  user = {
    develCuy = {
      username = 'root',
      password = 'unbreakable-password',
    },
  },
}

return m
