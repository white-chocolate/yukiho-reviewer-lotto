# Description:
#   assigns random reviewer for a pull request
#
# Configuration:
#   HUBOT_GITHUB_TOKEN (required)
#   HUBOT_GITHUB_ORG (required)
#   HUBOT_GITHUB_REVIEWER_TEAM (required)
#     github team id. this script randomly picks a reviewer from this team members.
#
# Commands:
#   hubot reviewer for <repo> <pull> - assigns random reviewer for pull request
#   hubot reviewer for <repo> <pull> <user> - assigns specified reviewer for pull request
#   hubot reviewer show stats - proves the lotto has no bias
#
# Author:
#   sakatam, white-chocolate

_         = require "underscore"
async     = require "async"
GitHubApi = require "github"

module.exports = (robot) ->
  ghToken       = process.env.HUBOT_GITHUB_TOKEN
  ghOrg         = process.env.HUBOT_GITHUB_ORG
  ghReviwerTeam = process.env.HUBOT_GITHUB_REVIEWER_TEAM

  STATS_KEY     = 'reviewer-lotto-stats'

  if !ghToken? or !ghOrg? or !ghReviwerTeam?
    return robot.logger.error """
      yukiho-reviewer-lotto に使われる環境変数がないよ!
      #{__filename}
      HUBOT_GITHUB_TOKEN: #{ghToken}
      HUBOT_GITHUB_ORG: #{ghOrg}
      HUBOT_GITHUB_REVIEWER_TEAM: #{ghReviwerTeam}
    """

  robot.respond /reviewer show stats$/i, (msg) ->
    stats = robot.brain.get STATS_KEY
    msgs = ["login, num assigned"]
    msgs.push "#{login}, #{count}" for login, count of stats
    msg.reply msgs.join "\n"

  robot.respond /reviewer for ([\w-\.]+) (\d+) in ([\w-\.]+)$/i, (msg) ->
    repo = msg.match[1]
    pr = msg.match[2]
    teamName = msg.match[3]
    prParams =
      user: ghOrg
      repo: repo
      number: pr

    gh = new GitHubApi version: "3.0.0"
    gh.authenticate { type: "oauth", token: ghToken }

    async.waterfall [
      (cb) ->
        # get teams
        params =
          org: ghOrg
        gh.orgs.getTeams params, (err, res) ->
          return cb "チームの取得に失敗しちゃったみたい。。: #{err.toString()}" if err?
          teamNames = res.map (t) -> t.name
          team = res.find (t) ->
            t.name == teamName
          if !team
            return cb "#{teamName} という名前のチームはないよ〜この中から選んでねっ♪: #{teamNames}"
          cb null, { team: team }
      (ctx, cb) ->
        # get team members
        params =
          id: ctx['team'].id
          per_page: 100
        gh.orgs.getTeamMembers params, (err, res) ->
          return cb "チームメンバーの取得に失敗しちゃったみたい。。: #{err.toString()}" if err?
          ctx['reviewers'] = res.map (r) -> r.login
          cb null, ctx

      (ctx, cb) ->
        # check if pull req exists
        gh.pullRequests.get prParams, (err, res) ->
          return cb "プルリクエストの取得に失敗しちゃったよ。。: #{err.toString()}" if err?
          ctx['issue'] = res
          ctx['creator'] = res.user
          ctx['assignee'] = res.assignee
          cb null, ctx

      (ctx, cb) ->
        # pick reviewer
        {reviewers, creator, assignee} = ctx
        reviewers = reviewers.filter (r) -> r != creator.login
        # exclude current assignee from reviewer candidates
        if assignee?
          reviewers = reviewers.filter (r) -> r != assignee.login
        if reviewers.length == 0
          return cb "割り当てられる人がいないみたい。。"
        ctx['reviewer'] = _.sample reviewers
        cb null, ctx

      (ctx, cb) ->
        # post a comment
        {reviewer} = ctx
        params = _.extend { body: "@#{reviewer} さん、レビューお願いっ！ :stuck_out_tongue_closed_eyes:" }, prParams
        gh.issues.createComment params, (err, res) -> cb err, ctx

      (ctx, cb) ->
        # change assignee
        {reviewer} = ctx
        params = _.extend { assignee: reviewer }, prParams
        gh.issues.edit params, (err, res) ->
          cb err, ctx

      (ctx, cb) ->
        {reviewer, issue} = ctx
        msg.send "#{reviewer} さんに #{issue.html_url} のレビューをお願いしたよっ♪"

        # update stats
        stats = (robot.brain.get STATS_KEY) or {}
        stats[reviewer.login] or= 0
        stats[reviewer.login]++
        robot.brain.set STATS_KEY, stats

        cb null, ctx

    ], (err, res) ->
      if err?
        msg.send "エラーが発生したよ！\n#{err}"


  robot.respond /reviewer for ([\w-\.]+) (\d+) ?([\w-\.]+)?$/i, (msg) ->
    repo     = msg.match[1]
    pr       = msg.match[2]
    reviewer = msg.match[3]
    prParams =
      user: ghOrg
      repo: repo
      number: pr

    gh = new GitHubApi version: "3.0.0"
    gh.authenticate {type: "oauth", token: ghToken}

    # mock api if debug mode
    if process.env.HUBOT_REVIEWER_LOTTO_DEBUG in ["1", "true"]
      gh.issues.createComment = (params, cb) ->
        console.log "GitHubApi - createComment is called", params
        cb null
      gh.issues.edit = (params, cb) ->
        console.log "GitHubApi - edit is called", params
        cb null

    async.waterfall [
      (cb) ->
        # get team members
        params =
          id: ghReviwerTeam
          per_page: 100
        gh.orgs.getTeamMembers params, (err, res) ->
          return cb "チームメンバーの取得に失敗しちゃったみたい。。: #{err.toString()}" if err?
          cb null, {reviewers: res.map (r) -> r.login}

      (ctx, cb) ->
        # check if pull req exists
        gh.pullRequests.get prParams, (err, res) ->
          return cb "プルリクエストの取得に失敗しちゃったよ。。: #{err.toString()}" if err?
          ctx['issue'] = res
          ctx['creator'] = res.user
          ctx['assignee'] = res.assignee
          cb null, ctx

      (ctx, cb) ->
        # pick reviewer
        {reviewers, creator, assignee} = ctx
        if reviewer?
          if reviewer not in reviewers
            return cb "#{reviewer} さんはそのチームにはいないよ〜この中から選んでねっ♪: #{reviewers}"
          ctx['reviewer'] = reviewer
          cb null, ctx
        else
          reviewers = reviewers.filter (r) -> r != creator.login
          # exclude current assignee from reviewer candidates
          if assignee?
            reviewers = reviewers.filter (r) -> r != assignee.login
          if reviewers.length == 0
            return cb "割り当てられる人がいないみたい。。"
          ctx['reviewer'] = _.sample reviewers
          cb null, ctx

      (ctx, cb) ->
        # post a comment
        {reviewer} = ctx
        params = _.extend { body: "@#{reviewer} さん、レビューお願いっ！ :stuck_out_tongue_closed_eyes:" }, prParams
        gh.issues.createComment params, (err, res) -> cb err, ctx

      (ctx, cb) ->
        # change assignee
        {reviewer} = ctx
        params = _.extend { assignee: reviewer }, prParams
        gh.issues.edit params, (err, res) ->
          cb err, ctx

      (ctx, cb) ->
        {reviewer, issue} = ctx
        msg.send "#{reviewer} さんに #{issue.html_url} のレビューをお願いしたよっ♪"

        # update stats
        stats = (robot.brain.get STATS_KEY) or {}
        stats[reviewer.login] or= 0
        stats[reviewer.login]++
        robot.brain.set STATS_KEY, stats

        cb null, ctx

    ], (err, res) ->
      if err?
        msg.send "エラーが発生したよ！\n#{err}"
