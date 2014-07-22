-- Warning! This file reloads everytime a message is received

local seawolf = require 'seawolf'.__build('variable', 'text')
local uuid = require 'uuid'
local empty = seawolf.variable.empty
local explode = seawolf.text.explode
local is_numeric = seawolf.variable.is_numeric
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
    url = ('%s://%s:%s@%s:%s/'):format(vault.devcoin.use_ssl and 'https' or 'http', vault.devcoin.user, vault.devcoin.password, vault.devcoin.server, vault.devcoin.port),
    method = 'POST',
    headers = { ['content-type'] = 'application/json', ['content-length'] = jsonRequest:len() },
    source = ltn12.source.string(jsonRequest),
    sink = ltn12.sink.table(chunks),
  }

  local response = tconcat(chunks)
  return ({json.decode(response)})[1]
end

local from
if channel and channel:sub(1, 1) == '#' then
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

function process(command, raw_params)
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
        irc:sendChat(irc_user.nick, 'usage: TIP <auth token> <nick> [<#channel>] [<amount>]')
      else
        local _ = (function(auth_token, nick, arg3, arg4)
          local amount, channel

          if empty(nick) then
            process 'TIP'
            return
          end

          if is_numeric(arg4) then
            amount = tonumber(arg4)
          elseif not empty(arg4) then
            if arg4:sub(1, 1) == '#' then
              channel = arg4
            -- When arg4 exits but isn't numeric
            else
              process 'TIP'
              return
            end
          end

          if is_numeric(arg3) then
            amount = tonumber(arg3)
          elseif not empty(arg3) then
            if arg3:sub(1, 1) == '#' then
              channel = arg3
            -- When arg3 exists but isn't numeric, nor a channel
            elseif not amount and not channel then
              process 'TIP'
              return
            end
            -- When arg4 exists and isn't numeric
            if not empty(arg4) and channel and not amount then
              process 'TIP'
              return
            end
          end

          amount = amount or 40
          if auth_token == tokens.auth[irc_user.nick] then
            local token = uuid.new()
            tokens.claim[token] = {
              nick = nick,
              amount = amount,
              donor = irc_user.nick,
            }
            if channel then
              irc:sendChat(channel, ('%s offers a tip of %s DVC to %s'):format(irc_user.nick, amount, nick))
            else
              irc:sendChat(irc_user.nick, ('Sending %s DVC to %s'):format(amount, nick))
            end
            irc:sendChat(nick, ('You got %s DVC from %s. Your claim token is: %s'):format(amount, irc_user.nick, token))
            irc:sendChat(nick, 'usage: CLAIM <claim token> <tip address>')
          else
            irc:sendChat(irc_user.nick, 'error: Invalid auth token!')
          end
        end)(params[1], params[2], params[3], params[4])
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
                local txid = rs and rs.result or ''
                irc:sendChat(claim.donor, ('%s DVC delivered to %s. http://d.evco.in/abe/tx//%s'):format(claim.amount, claim.nick, txid))
                irc:sendChat(claim.nick, ('Sent %s DVC to %s. http://d.evco.in/abe/tx//%s'):format(claim.amount, tip_address, txid))
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
              process 'JOIN'
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

process(command, raw_params)

print 'DEBUG: done.'