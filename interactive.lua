-- Warning! This file reloads everytime a message is received

local seawolf = require 'seawolf'.__build('variable', 'text')
local uuid = require 'uuid'
local empty = seawolf.variable.empty
local explode = seawolf.text.explode
local print_r = seawolf.variable.print_r -- Debug helper
local http, ltn12 = require 'socket.http', require 'ltn12'
local tconcat, json = table.concat, require 'dkjson'

local irc_user = _G.user
local channel = _G.channel
local message = _G.message
local irc = _G.irc

local _, vault = pcall(require, 'vault')
if _G.tokens == nil then
  _G.tokens = {
    auth = {},
    claim = {},
  }
end
local tokens = _G.tokens


local function api_call(method, params)
  local request = {
    id = 'httpRequest',
    method = method,
    params = params or {},
  }
  local jsonRequest = json.encode(request)
  local chunks = {}

  local r, c, h = http.request{
    url = ('http://%s:%s@%s:%s/'):format(vault.devcoin.user, vault.devcoin.password, vault.devcoin.server, vault.devcoin.port),
    method = 'POST',
    headers = { ['content-type'] = 'application/json', ['content-length'] = jsonRequest:len() },
    source = ltn12.source.string(jsonRequest),
    sink = ltn12.sink.table(chunks),
  }

  local response = tconcat(chunks)
  return ({json.decode(response)})[1]
end

local from
if channel:sub(1, 1) == '#' then
  from = 'chan'
else
  from = 'nick'
end

local command, raw_params = (function (message)
  local pos = message:find ' '

  -- Shift nick from message when command comes from a channel
  if from == 'chan' then
    local command = message:sub(1, pos -1)
    if command == vault.irc.nick or command == vault.irc.nick .. ':' or command == vault.irc.nick .. ',' then
      message = message:sub(pos + 1)
      pos = message:find ' '
    end
  end

  if pos then
    return message:sub(1, pos -1), message:sub(pos + 1)
  else
    return message
  end
end)(message)

function proccess(command, raw_params)
  local params = explode(' ', raw_params)
  
  if from == 'chan' then
    if command == 'TIP' then
      irc:sendChat(channel, ("%s: I'm glad to serve you over PM."):format(irc_user.nick))
    end
  elseif from == 'nick' then
    if command == 'AUTH' then
      if empty(raw_params) then
        irc:sendChat(irc_user.nick, 'usage: AUTH <password>')
      else
        local user = vault.user[irc_user.nick]
        if irc_user.nick == user.username and raw_params == user.password then
          local token = uuid.new()
          tokens.auth[irc_user.nick] = token
          irc:sendChat(irc_user.nick, ('your new auth token: %s'):format(token))
        else
          irc:sendChat(irc_user.nick, 'error: Invalid password!')
        end
      end
    elseif command == 'TIP' then
      if empty(raw_params) then
        irc:sendChat(irc_user.nick, 'usage: TIP <auth token> <nick> [<amount>]')
      else
        local _ = (function(auth_token, nick, channel, amount)
          amount = amount or 4
          if auth_token == tokens.auth[irc_user.nick] then
            local token = uuid.new()
            tokens.claim[token] = {
              nick = nick,
              amount = amount,
              donor = irc_user.nick,
            }
            irc:sendChat(nick, ('You got %s DVC from %s. Your claim token is: %s'):format(amount, irc_user.nick, token))
            irc:sendChat(nick, 'usage: CLAIM <claim token> <tip address>')
          else
            irc:sendChat(nick, 'error: Invalid auth token!')
          end
        end)(params[1], params[2], params[3])
      end
    elseif command == 'CLAIM' then
      if empty(raw_params) then
        irc:sendChat(irc_user.nick, 'usage: CLAIM <claim token> <tip address>')
      else
        local _ = (function(token, tip_address)
          local claim = tokens.claim[token]
          if claim and claim.nick == irc_user.nick then
            if empty(tip_address) then
              irc:sendChat(irc_user.nick, 'error: Invalid tip address!')
              process 'CLAIM'
            else
              local rs = api_call('sendtoaddress', {tip_address, claim.amount})
              if rs.code then
                irc:sendChat(claim.nick, "error: Can't deliver tip! please try again later.")
              else
                tokens.claim[token] = nil
                irc:sendChat(claim.donor, ('Your tip was delivered to %s. Transaction ID: %s'):format(claim.nick, rs.result))
                irc:sendChat(claim.nick, ('Sent %s DVC to %s'):format(claim.amount, tip_address))
              end
            end
          else
            irc:sendChat(irc_user.nick, 'error: Invalid claim token!')
          end
        end)(params[1], params[2])
      end
    elseif command == 'JOIN' then
      if empty(raw_params) then
        irc:sendChat(irc_user.nick, 'usage: JOIN <auth token> <#channel> [<key>]')
      else
        local _ = (function(auth_token, channel, key)
          if auth_token == tokens.auth[irc_user.nick] then
            if empty(channel) or channel:sub(1, 1) ~= '#' then
              irc:sendChat(irc_user.nick, 'error: Invalid channel!')
              proccess 'JOIN'
            elseif not empty(key) then
              irc:join(channel, key)
            else
              irc:join(channel)
            end
          else
            irc:sendChat(irc_user.nick, 'error: Invalid auth token!')
          end
        end)(params[1], params[2], params[3])
      end
    end
  end
end

proccess(command, raw_params)

print 'DEBUG: done.'