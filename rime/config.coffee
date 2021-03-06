jsyaml = require 'js-yaml'

exports.Config = class Config
  constructor: (yaml) ->
    @root = if yaml then jsyaml.safeLoad yaml else null

  loadFileSync: (filePath) ->
    data = fs.readFileSync filePath, {encoding: 'utf8'}
    # remove potential BOM character
    yaml = data.replace /^\ufeff/, ''
    @root = jsyaml.safeLoad yaml, filename: filePath
    return @

  loadFile: (filePath) ->
    new Promise (resolve, reject) =>
      fs.readFile filePath, {encoding: 'utf8'}, (err, data) =>
        if err
          console.error "error loading config: #{err}"
          reject err
          return
        # remove potential BOM character
        yaml = data.replace /^\ufeff/, ''
        try
          @root = jsyaml.safeLoad yaml, filename: filePath
        catch err
          console.error "error loading config: #{err}"
          reject err
          return
        resolve()

  saveFile: (filePath) ->
    new Promise (resolve, reject) =>
      fs.writeFile filePath, @toString(), (err) ->
        if err
          reject err
        else
          resolve()

  toString: ->
    jsyaml.safeDump @root, flowLevel: 3

  get: (key) ->
    ks = (x for x in key.split '/' when x)
    if ks.length == 0  # '', '/'
      return @root
    node = @root
    for k in ks
      break unless node?
      node = node[k]
    node

  set: (key, value) ->
    ks = (x for x in key.split '/' when x)
    if ks.length == 0  # '', '/'
      return @root = value
    @root ?= {}
    node = @root
    kend = ks.pop()
    for k in ks
      node[k] = {} unless node[k]?
      node = node[k]
    node[kend] = value
