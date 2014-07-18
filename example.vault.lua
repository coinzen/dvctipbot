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

  -- Users granted to send tips
  user = {
    develCuy = {
      username = 'root',
      password = 'unbreakable-password',
    },
  },
}

return m
