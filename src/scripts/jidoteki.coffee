# Description:
#   Build virtual appliances using Jidoteki
#   http://jidoteki.com
#
# Configuration
#   JIDOTEKI_USERID = your 7 character user id
#   JIDOTEKI_APIKEY = your 64 character API key
#   JIDOTEKI_ROLE   = a privileged role to use the API, defaults to 'op'
#
# Commands:
#   hubot jido os list
#   hubot jido image list
#
# Author:
#   aw

crypto    = require 'crypto'
util      = require 'util'

jido = exports ? this

module.exports = (robot) ->
  jido.settings =
    userid:     process.env.JIDOTEKI_USERID
    apikey:     process.env.JIDOTEKI_APIKEY
    role:       process.env.JIDOTEKI_ROLE || 'op'
    url:        'https://api.beta.jidoteki.com/v0'
    useragent:  'hubot-jidoteki/0.1'
    token:      null

  unless jido.settings.userid? or jido.settings.apikey?
    console.log "JIDOTEKI_ environment variables are not configured. More info at: http://jidoteki.com"
    return

  makeHMAC = (string, callback) ->
    hmac = crypto.createHmac('sha256', jido.settings.apikey).update(string).digest 'hex'
    callback(hmac)

  getToken = (callback) ->
    resource = '/auth/user'
    makeHMAC "GET#{jido.settings.url}#{resource}", (signature) ->
      robot.http("#{jido.settings.url}#{resource}")
        .headers
          'X-Auth-UID': jido.settings.userid
          'X-Auth-Signature': signature
          'User-Agent': jido.settings.useragent
        .get() (err, res, body) ->
          data = JSON.parse body
          if data.success
            jido.settings.token = data.success.content
            setTimeout ->
              jido.settings.token = null
            , 27000000 # Expire the token after 7.5 hours
          callback data

  getData = (type, resource, callback) ->
    makeHMAC "#{type.toUpperCase()}#{jido.settings.url}#{resource}", (signature) ->
      robot.http("#{jido.settings.url}#{resource}")
        .headers
          'X-Auth-Token': jido.settings.token
          'X-Auth-Signature': signature
          'User-Agent': jido.settings.useragent
        .get() (err, res, body) ->
          data = JSON.parse body
          jido.settings.token = null if data.error and data.error.message is 'Unable to authenticate'
          callback data

  makeRequest = (type, resource, callback) ->
    if jido.settings.token isnt null
      getData type, resource, (data) ->
        callback data
    else
      getToken (result) ->
        getData type, resource, (data) ->
          callback data

  requireAuth = (robot, msg) ->
    role = robot.auth.hasRole msg.envelope.user, jido.settings.role
    return true unless role is false
    msg.reply "Sorry, you need the '#{jido.settings.role}' role to perform that command."
    return false

  robot.respond /jido os list/i, (msg) ->
    msg.send "Fetching Operating Systems list"
    makeRequest 'GET', '/os/list', (data) ->
      if data.success
        os_list = data.success.content
        # format the OS list into a table
        output  = "| OS Name\t| Architecture | os_id |\n"
        output += "|---------------------------------------|\n"
        for os of os_list
          for arch of os_list[os]
            for result in os_list[os][arch]
              output += util.format "| %s | %s | %s |\n",
                result.os_name,
                result.os_arch,
                result.os_id
        msg.send output
      else
        msg.send data.error.message

  robot.respond '/jido image list/i', (msg) ->
    return unless requireAuth(robot, msg)

    msg.send "Fetching 10 most recent servers.."
    makeRequest 'GET', '/server/list', (data) ->
      if data.success
        server_list = data.success.content[0..9] # limit to only 10 results
        # format the server list into a table
        output  = "| ID\t\t| Date\t| Status / % | Name |\n"
        output  += "|-----------------------------------------------------------------------------|\n"
        for server in server_list
          output += util.format "| %s | %s | %s / %s% | %s |\n",
            server.server_id,
            new Date(server.created_timestamp*1000),
            server.build.status,
            server.build.pct_complete,
            server.name
        msg.send output
      else
        msg.send data.error.message
