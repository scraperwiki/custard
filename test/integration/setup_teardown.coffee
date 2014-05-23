{parallel} = require 'async'
cleaner = require '../cleaner'
check_for_cobalt = require '../check_for_cobalt'
{wd40, browser} = require 'wd40'

base_url = process.env.CU_TEST_URL ? 'http://localhost:3001'
login_url = "#{base_url}/login"
logout_url = "#{base_url}/logout"

before (done) ->
    console.log "[scraperwiki global before]"

    parallel [
      (cb) ->
        check_for_cobalt.check ->
          cb()
      (cb) ->
        cleaner.clear_and_set_fixtures ->
          cb()
      (cb) ->
        wd40.init ->
          browser.get base_url, ->
            cb()
    ], done

after (done) ->
    console.log "[scraperwiki global after]"
    browser.quit done
