fs = require('fs')

stringDiff = (x, element, attrs) ->
  oldValue = x?.previous?.toString() ? ''
  newValue = x?.toString() ? ''
  if oldValue == newValue
    element.text newValue
    return
  diffMethod =
    if attrs.unit is 'char' then JsDiff.diffChars else JsDiff.diffWords
  changes = diffMethod(oldValue, newValue)
  element.html JsDiff.convertChangesToXML(changes)

scriptDiff = (x, element, attrs) ->
  unless x?.previous?
    element.text x?.toString() ? ''
    return
  escapeHTML = JsDiff.escapeHTML
  compareSpellingByText = (a, b) ->
    if a.text < b.text then -1 else if a.text > b.text then 1 else 0
  os = x.previous.getSpellings().sort compareSpellingByText
  ns = x.getSpellings().sort compareSpellingByText
  changes = []
  while os.length > 0 and ns.length > 0
    ot = os[0].text
    nt = ns[0].text
    if ot < nt
      os.shift()
      changes.push '<del>' + escapeHTML(ot) + '</del>'
    else if ot > nt
      ns.shift()
      changes.push '<ins>' + escapeHTML(nt) + '</ins>'
    else
      if os.shift() isnt ns.shift()
        changes.push '<em>' + escapeHTML(nt) + '</em>'
      else  # no change
        changes.push escapeHTML(nt)
  while os.length > 0
    changes.push '<del>' + escapeHTML(os.shift().text) + '</del>'
  while ns.length > 0
    changes.push '<ins>' + escapeHTML(ns.shift().text) + '</ins>'
  element.html changes.join ' '

app.directive 'diff', ->
  restrict: 'E'
  link: (scope, element, attrs) ->
    scope.$watch attrs.value, (x) ->
      if attrs.type is 'script'
        scriptDiff(x, element, attrs)
      else
        stringDiff(x, element, attrs)

app.directive 'query', ->
  restrict: 'E'
  scope:
    update: '&'
    visible: '@'
  template: '''<div ng-show="visible">
    <form class="form-search" style="margin: 20px;">
      <div class="input-append">
        <input type="text" class="span2 search-query" ng-trim="false" ng-model="value">
        <button type="submit" class="btn" ng-click="update({query:value})">查詢</button>
      </div>
    </form>
  </div>'''

app.controller 'AlgebraCtrl', ($scope, rimekitService) ->
  $scope.configKeys = [
    'speller/algebra'
    'translator/preedit_format'
    'translator/comment_format'
    'reverse_lookup/preedit_format'
    'reverse_lookup/comment_format'
  ]

  $scope.rimeDirectory = rimekitService.rimeDirectory
  $scope.schemaId = 'luna_pinyin'
  $scope.configKey = 'speller/algebra'
  $scope.rules = []
  $scope.syllabary = []
  $scope.alerts = []

  $scope.init = ->

  $scope.loadSchema = ->
    @rules = []
    @syllabary = []
    @alerts.length = 0
    return unless @schemaId && @configKey
    filePath = "#{@rimeDirectory ? '.'}/#{@schemaId}.schema.yaml"
    unless fs.existsSync filePath
      console.warn "file does not exist: #{filePath}"
      @alerts.push type: 'error', msg: '找不到輸入方案'
      return
    config = new Config
    config.loadFile filePath, (loaded) =>
      @$apply =>
        unless loaded
          @alerts.push type: 'error', msg: '載入輸入方案錯誤'
          return
        @dictName = config.get 'translator/dictionary' ? ''
        rules = config.get @configKey
        @rules = (new Rule(x) for x in rules) if rules
        console.log "#{@rules.length} rules loaded."
        if @rules.length != 0
          @rules.unshift new Rule  # initial state
        @isProjector = @configKey.match(/\/algebra$/) != null
        @isFormatter = @configKey.match(/format$/) != null
        @calculate()

  $scope.loadDict = ->
    @syllabary = []
    @alerts.length = 0
    return unless @dictName
    filePath = "#{@rimeDirectory ? '.'}/#{@dictName}.table.bin"
    table = new Table
    table.loadFile filePath, (syllabary) =>
      @$apply =>
        unless syllabary
          @alerts.push type: 'error', msg: '載入詞典錯誤'
          return
        @syllabary = syllabary
        console.log "#{@syllabary.length} syllables loaded."
        @calculate()

  $scope.calculate = ->
    if @rules.length == 0
      @alerts.push type: 'error', msg: '無有定義拼寫運算規則'
      return
    algebra = new Algebra @rules
    if @isProjector and @syllabary.length
      console.log "calulate: [#{@syllabary.length} syllables]"
      algebra.makeProjection Script.fromSyllabary @syllabary
      for r in @rules
        r.queryResult = r.script
    if @isFormatter and @testString
      console.log "calulate: \"#{@testString}\""
      algebra.formatString @testString ? ''

  $scope.closeAlert = (index) ->
    @alerts.splice index, 1

  $scope.querySpellings = (index, pattern) ->
    console.log "querySpellings: #{index}, \"#{pattern}\""
    return unless @rules[index]?.script

    p = null
    if pattern
      try
        p = new RegExp pattern
      catch error
        console.error "bad query: #{error}"

    unless p
      for r in @rules
        r.queryResult = r.script
      console.log 'cleared query result.'
      return

    q = @rules[index].queryResult = @rules[index].script.query p

    r = q
    for j in [index - 1..0] by -1
      r = @rules[j].queryResult = r.queryPrevious @rules[j].script

    r = q
    for j in [index + 1...@rules.length]
      r = @rules[j].queryResult = r.queryNext @rules[j].script
