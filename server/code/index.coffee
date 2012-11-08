express = require 'express'
stylus = require 'stylus'
assets = require 'connect-assets'
cons = require 'consolidate'

app = express()
# Add Connect Assets
app.use assets({src: 'client'})
# Set the public folder as static assets
app.use express.static(process.cwd() + '/shared')
# Set View Engine
app.set 'views', 'server/template'
app.engine 'html', cons.jazz
app.set 'view engine', 'html'
js.root = 'code'

# Avoids "Error: Cannot find module 'ico'"
app.get '/favicon.ico', (req, resp) -> resp.send 404

# TODO: sort out nice way of serving templates
app.get '/tpl/:page', (req, resp) ->
  resp.render req.params.page

app.get '*', (req, resp) ->
  resp.render 'index', { scripts: js 'app' }

# Define Port
port = process.env.PORT or process.env.VMC_APP_PORT or 3000
# Start Server
app.listen port, ->
  console.log "Listening on #{port}\nPress CTRL-C to stop server."
