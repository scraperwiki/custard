class Cu.View.ToolContent extends Backbone.View
  id: 'fullscreen'

  initialize: ->
    @model.on 'update:tool', @googleAnalytics, @
    @googleAnalytics()

  render: ->
    $('body').addClass('fullscreen')
    @positionIframe()
    @

  positionIframe: ->
    # Work out correct position for fullscreen iframe, accounting for injected lastpass bars etc.
    # This is also called in Cu.View.Toolbar, after the toolbar has loaded, just in case.
    $c = $('#content')
    @$el.css 'top', $c.offset().top - $c.outerHeight(true) - $c.innerHeight()

  showContent: ->
    @boxUrl = @model.endpoint()
    @settings (settings) =>
      frag = encodeURIComponent JSON.stringify(settings)
      @setupEasyXdm "#{@boxUrl}/#{@model.get 'box'}/#{settings.source.publishToken}/container.html##{frag}"
      @positionIframe()

  close: ->
    $('body').removeClass('fullscreen')
    super()

  googleAnalytics: ->
    if @model.get('tool')
      toolName = @model.get('tool').get 'name'
      _gaq.push ['_trackEvent', 'tools', 'render', toolName]

  setupEasyXdm: (url) ->
    transport = new easyXDM.Rpc
      remote: url
      container: document.getElementById('fullscreen')
    ,
      local:
        ###
        Note: If you ever add a function here, you also need to list it in
        cobalt in container.html.
        ###
        redirect: (url) ->
          isExternal = new RegExp('https?://')
          if isExternal.test url
            location.href = url
          else
            window.app.navigate url, trigger: true
        getURL: (cb) ->
          cb window.location.href
        rename: (box, name) ->
          app.tools().fetch
            success: ->
              mod = Cu.Model.Dataset.findOrCreate box: box
              mod.fetch
                success: (model, resp, options) ->
                  model.set 'displayName', name
                  model.save()
                  _gaq.push ['_trackEvent', 'datasets', 'rename-xdm', name]
        getName: (box, cb) ->
          console.log('XDM getName() called')
          app.tools().fetch
            success: ->
              console.log('XDM getName() -> app.tools() fetched')
              mod = Cu.Model.Dataset.findOrCreate box: box
              mod.fetch
                success: (model, resp, options) ->
                  console.log('XDM getName() -> model fetched')
                  console.log('displayName', model.get 'displayName')
                  cb null, model.get 'displayName'
              return undefined # required to make xdm wait for callbacks
          return undefined # required to make xdm wait for callbacks
        pushSQL: (query, toolName) =>
          # TODO: passing via a global variable is ickly
          window.app.pushSqlQuery = query

          app.tools().fetch
            success: (tools, resp, options) ->
              tool = app.tools().findByName toolName
              # TODO: DRY with tool tile install
              dataset = Cu.Model.Dataset.findOrCreate
                displayName: tool.get('manifest').displayName
                tool: tool

              dataset.new = true

              dataset.save {},
                wait: true
                success: ->
                  delete dataset.new
                  window.app.navigate "/dataset/#{dataset.id}/settings", {trigger: true}
        getUserDetails: (cb) ->
          cb
            real:
              shortName: window.user.real.shortName
              displayName: window.user.real.displayName
              email: window.user.real.email[0]
              accountLevel: window.user.real.accountLevel
            effective:
              shortName: window.user.effective.shortName
              displayName: window.user.effective.displayName
              email: window.user.effective.email[0]
              accountLevel: window.user.effective.accountLevel
        reportingMessage: (message, success, error) ->
          $.ajax
            type: 'POST'
            url: '/api/reporting/message/'
            data:
              url: window.location.href
              message: message
            success: ->
              if typeof success is 'function'
                success()
            error: ->
              if typeof error is 'function'
                error()
          undefined # required to stop easyXDM calling the success callback
        reportingUser: (payload, success, error) ->
          $.ajax
            type: 'POST'
            url: '/api/reporting/user/'
            data: payload
            success: ->
              if typeof success is 'function'
                success()
            error: ->
              if typeof error is 'function'
                error()
          undefined # required to stop easyXDM calling the success callback
        reportingTag: (tagname, success, error) ->
          $.ajax
            type: 'POST'
            url: '/api/reporting/tag/'
            data:
              name: tagname
            success: ->
              if typeof success is 'function'
                success()
            error: ->
              if typeof error is 'function'
                error()
          undefined # required to stop easyXDM calling the success callback


class Cu.View.AppContent extends Cu.View.ToolContent
  settings: (callback) ->
    dataset = @model
    datasetEndpoint = dataset.endpoint()
    datasetBox = dataset.get 'box'
    datasetToken = dataset.get('boxJSON')?.publish_token

    query = window.app.pushSqlQuery
    window.app.pushSqlQuery = null

    displayName = @model.get('displayName')
    callback
      source:
        apikey: window.user.effective.apiKey
        url: "#{datasetEndpoint}/#{datasetBox}/#{datasetToken}"
        publishToken: datasetToken
        box: datasetBox
        sqlQuery: query
        displayName: displayName


class Cu.View.PluginContent extends Cu.View.ToolContent
  settings: (callback) ->
    view = @model
    viewEndpoint = view.endpoint()
    viewBox = view.get 'box'
    viewToken = view.get('boxJSON')?.publish_token

    dataset = @model.get 'plugsInTo'
    datasetEndpoint = dataset.endpoint()
    datasetBox = dataset.get 'box'
    datasetToken = dataset.get('boxJSON')?.publish_token

    query = window.app.pushSqlQuery
    window.app.pushSqlQuery = null

    displayName = dataset.get('displayName')
    callback
      source:
        apikey: window.user.effective.apiKey
        url: "#{viewEndpoint}/#{viewBox}/#{viewToken}"
        publishToken: viewToken
        box: viewBox
        sqlQuery: query
        displayName: displayName
      target:
        url: "#{datasetEndpoint}/#{datasetBox}/#{datasetToken}"
        publishToken: datasetToken
        box: datasetBox
