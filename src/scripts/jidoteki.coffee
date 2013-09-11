# Description:
#   Build virtual appliances using Jidoteki
#   http://jidoteki.com
#
# Installation:
#   add jidoteki as a dependency in your package.json
#   or: npm install jidoteki
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

util      = require 'util'
jidoteki  = require 'jidoteki'

jidoteki.settings.useragent = 'hubot-jidoteki/0.3'
jidoteki.settings.role = process.env.JIDOTEKI_ROLE || 'op'

module.exports = (robot) ->
  requireAuth = (robot, msg) ->
    role = robot.auth.hasRole msg.envelope.user, jidoteki.settings.role
    return true unless role is false
    msg.reply "Sorry, you need the '#{jidoteki.settings.role}' role to perform that command."
    return false

  robot.respond /jido os list/i, (msg) ->
    msg.send "Fetching Operating Systems list"
    jidoteki.makeRequest 'GET', '/os/list', (data) ->
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
    jidoteki.makeRequest 'GET', '/server/list', (data) ->
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
