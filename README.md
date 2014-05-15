# yukiho-reviewer-lotto
Yukiho assigns a (random) reviewer for pull request on behalf of you.

This is a fork of [sakatam/hubot-reviewer-lotto](https://github.com/sakatam/hubot-reviewer-lotto).

# preparation
* create a reviewer team in your github organization

# installation
* add `"yukiho-reviewer-lotto": "git://github.com/white-chocolate/yukiho-reviewer-lotto.git"` to Yukiho's `package.json`
* add `"yukiho-reviewer-lotto"` to your `external-scripts.json`
* set up the following env vars on heroku
    * `HUBOT_GITHUB_TOKEN`
    * `HUBOT_GITHUB_ORG` - name of your github organization
    * `HUBOT_GITHUB_REVIEWER_TEAM` - the reviewer team id that you have created above

# usage
* `yukiho reviewer for <repo> <pull>`
    * e.g. `yukiho reviewer for our-webapp 345`
* `yukiho reviewer for <repo> <pull> <user>`
    * e.g. `yukiho reviewer for our-webapp 345 octocat`
