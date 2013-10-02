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


class Cu.View.AppContent extends Cu.View.ToolContent
  settings: (callback) ->
    dataset = @model
    datasetEndpoint = dataset.endpoint()
    datasetBox = dataset.get 'box'
    datasetToken = dataset.get('boxJSON')?.publish_token

    query = window.app.pushSqlQuery
    window.app.pushSqlQuery = null

    callback
      source:
        apikey: window.user.effective.apiKey
        url: "#{datasetEndpoint}/#{datasetBox}/#{datasetToken}"
        publishToken: datasetToken
        box: datasetBox
        sqlQuery: query


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
      target:
        url: "#{datasetEndpoint}/#{datasetBox}/#{datasetToken}"
        publishToken: datasetToken
        box: datasetBox
        displayName: displayName
