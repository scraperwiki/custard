child_process = require 'child_process'
fs = require 'fs'
exists = fs.exists or path.exists

async = require 'async'
request = require 'request'
rimraf = require 'rimraf'

mongoose = require 'mongoose'
Schema = mongoose.Schema

{Dataset} = require 'model/dataset'

ModelBase = require 'model/base'

toolSchema = new Schema
  name:
    type: String
    index: unique: true
  user: String
  type: String
  gitUrl: String
  public: {type: Boolean, default: false}
  allowedUsers: [String]
  manifest: Schema.Types.Mixed
  created:
    type: Date
    default: Date.now
  updated: Date

zDbTool = mongoose.model 'Tool', toolSchema

class exports.Tool extends ModelBase
  @dbClass: zDbTool

  gitCloneOrPull: (options, callback) ->
    @directory = "#{options.dir}/#{@name}"
    # :todo: whitelist @directory
    fs.exists @directory, (exists) =>
      if not exists
        cmd = "git clone #{@gitUrl} #{@directory}; cd #{@directory}"
      else
        cmd = "cd #{@directory}; git pull"
      cmd += "; chown -R www-data:www-data ." if process.env.NODE_ENV?
      child_process.exec cmd, callback

  # TODO: DRY
  gitCloneIfNotExists: (options, callback) ->
    @directory = "#{options.dir}/#{@name}"
    # :todo: whitelist @directory
    fs.exists @directory, (exists) =>
      if not exists
        cmd = "git clone #{@gitUrl} #{@directory}; cd #{@directory}"
        cmd += "; chown -R www-data:www-data ."
        child_process.exec cmd, callback
      else
        callback null, null

  updateInstances: (done) ->
    {Box} = require 'model/box'
    {User} = require 'model/user' # Avoids circular dependency
    # updates all of the boxes on cobalt that use this tool.
    if @type == 'importer'
      M = Dataset
    else if @type == 'view'
      M = Dataset.View
    else
      console.warn "unexpected tool type"
      return done "tooltypewrong"
    M.findAllByTool @name, (err, datasets) =>
      async.forEach datasets, (item, cb) =>
        User.findByShortName item.user, (err, user) =>
          if err? or not user?
            cb err or "no user"
          else
            request.post
              uri: "#{Box.endpoint item.boxServer, item.box}/exec"
              form:
                apikey: user.apikey
                cmd: "cd ~/tool && git pull >> tool-update.log 2>&1"
            , cb
      , done

  loadManifest: (callback) ->
    fs.exists @directory, (isok) =>
      if not isok
        callback 'not cloned'
        return
      fs.readFile "#{@directory}/scraperwiki.json", (err, data) =>
        if err
          callback err
          return
        try
          @manifest = JSON.parse data
        catch error
          callback error: json: error
        callback null

  deleteRepo: (callback) ->
    rimraf @directory, callback

  save: (callback) ->
    @updated = Date.now()
    super callback

  @findOneById: (id, callback) ->
    @dbClass.findOne {_id: id}, (err, doc) =>
      if doc is null
        callback err, null
      else
        callback null, @makeModelFromMongo doc

  @findOneByName: (name, callback) ->
    @dbClass.findOne {name: name}, (err, doc) =>
      if doc is null
        callback err, null
      else
        callback null, @makeModelFromMongo doc

  @findOneForUser: (args, callback) ->
    @dbClass.findOne
      name: args.name
      $or: [
        {user: args.user.shortName}
        {public: true}
        allowedUsers: { $in:  [args.user.shortName] }
      ]
    , (err, doc) =>
      if doc is null
        callback err, null
      else
        callback null, @makeModelFromMongo doc

  @findForUser: (shortName, cb) ->
    @dbClass.find $or: [{user: shortName}, {public: true}, {allowedUsers: { $in:  [shortName]}}], (err, docs) =>
      if docs is null
        cb err, null
      else
        result = (@makeModelFromMongo(doc) for doc in docs)
        cb null, result

exports.dbInject = (dbObj) ->
  Tool.dbClass = zDbBox = dbObj
  Tool
