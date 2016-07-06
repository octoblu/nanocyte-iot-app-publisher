_             = require 'lodash'
debug         = require('debug')('nanocyte-iot-app-publisher')
MeshbluHttp   = require 'meshblu-http'
MeshbluConfig = require 'meshblu-config'

class IotAppPublisher
  constructor: (options, dependencies={}) ->
    {
      @appId
      @appToken
      @flowId
      @flowToken
      @version
      meshbluConfig
    } = options
    {
      @configurationSaver
      @configurationGenerator
      MeshbluHttp
    } = dependencies

    MeshbluHttp   ?= require 'meshblu-http'
    meshbluConfig ?= new MeshbluConfig
    meshbluJSON   = _.assign meshbluConfig.toJSON(), uuid: @appId, token: @appToken
    @meshbluHttp  = new MeshbluHttp meshbluJSON

  publish: (callback=->) =>
    @getFlowDevice (error, flowDevice) =>
      return callback error if error?
      flowData = flowDevice.draft
      @configurationGenerator.configure {flowData, @flowToken}, (error, config, stopConfig) =>
        debug("Error generating config for flow", error) if error?
        return callback error if error?
        @clearAndSaveConfig {config, stopConfig}, callback



  clearAndSaveConfig: (options, callback) =>
    {config, stopConfig} = options

    saveOptions =
      appId: @appId
      version: @version
      flowData: config

    @configurationSaver.saveIotApp saveOptions, callback

  getFlowDevice: (callback) =>

    query = uuid: @flowId

    projection = uuid: true, draft: true

    @meshbluHttp.search query, {projection}, (error, devices) =>
      return callback error if error?
      flowDevice = _.first devices
      unless flowDevice?
        error = new Error 'Device Not Found'
        error.code = 404
        return callback error
      unless flowDevice?.draft
        error = new Error 'Device is missing flow property'
        error.code = 400
        return callback error
      callback null, flowDevice

  setupDevice: ({flowData, config}, callback=->) =>
    @setupMessageSchema flowData.nodes, callback

  buildFormTitleMap: (triggers) =>
    _.transform triggers, (result, trigger) ->
      triggerId = _.first trigger.id.split /-/
      result[trigger.id] = "#{trigger.name} (#{triggerId})"
    , {}

  setupMessageSchema: (nodes, callback=->) =>
    triggers = _.filter nodes, class: 'trigger'

    messageSchema =
      type: 'object'
      'x-form-schema': 'message.default.angular'
      properties:
        metadata:
          type: 'object'
          properties:
            to:
              type: 'string'
              title: 'Trigger'
              required: true
              enum: _.map(triggers, 'id')
        payload:
          title: "payload"
          description: "Use {{msg}} to send the entire message"

    messageFormSchema = [
      { key: 'metadata.to', titleMap: @buildFormTitleMap triggers }
      { key: 'payload', 'type': 'input', title: "Payload", description: "Use {{msg}} to send the entire message"}
    ]

    setMessageSchema =
      $set:
        instanceId: @instanceId
        bluprint:
          schemas:
            version: '2.0.0'
            form:
              message:
                default:
                  angular: messageFormSchema
            message:
              default: messageSchema


    @meshbluHttp.updateDangerously @appId, setMessageSchema, callback

module.exports = IotAppPublisher
