class Cu.View.SetPassword extends Backbone.View
  className: "set-password"

  events:
    'click .btn-primary': 'setPassword'

  render: ->
    @el.innerHTML = JST['set-password'] @options
    @

  setPassword: (e) ->
    e.preventDefault()
    password = $('#password').val()
    @$el.find('.alert').remove()
    @$el.find('.control-group').removeClass('error')
    token = location.pathname.split('/')
    token = token[token.length-1]
    $button = $(e.target)
    if password!=''
      $button.attr('disabled', true).addClass('loading').html('Setting Password&hellip;')
      $.ajax
        url: "#{location.protocol}//#{location.host}/api/token/#{token}"
        data:
          password: password
        type: 'POST'
        dataType: 'json'
        success: (profile) =>
          window.location = '/datasets'
        error: (jqxhr, textStatus, errorThrown) =>
          @$el.children('form').prepend """<div class="alert"><strong>Oh no! Something went wrong.</strong> Are you sure you clicked the right link?</div>"""
          $button.attr('disabled', false).removeClass('loading').html('<i class="icon-ok space"></i> Try Again')
    else
      @$el.find('.control-group').addClass('error').children('label').text('You must supply a password:').next().focus()
