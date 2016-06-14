_                   = require 'lodash'
debug               = require('debug')('nanocyte-iot-app-publisher')

NanocyteConfigurationGenerator = require 'nanocyte-configuration-generator'
NanocyteConfigurationSaver     = require 'nanocyte-configuration-saver-redis'
MeshbluHttp                    = require 'meshblu-http'
MeshbluConfig                  = require 'meshblu-config'

class IotAppPublisher
  constructor: (options) ->
    {
      @flowUuid
      @version
      @flowToken
      @userUuid
      @userToken
      @octobluUrl
      @client
    } = options

    meshbluConfig = new MeshbluConfig
    meshbluJSON   = _.assign meshbluConfig.toJSON(), uuid: @flowUuid, token: @flowToken
    @meshbluHttp  = new MeshbluHttp meshbluJSON

    throw new Error 'IotAppPublisher requires client' unless @client?

  publish: (callback=->) =>
    @getFlowDevice (error) =>
      return callback error if error?
      flowData = @flowDevice.flow
      @configurationGenerator.configure {flowData, @flowToken, @deploymentUuid}, (error, config, stopConfig) =>
        debug 'configurationGenerator.configure', @benchmark.toString()
        return callback error if error?

        @clearAndSaveConfig {config, stopConfig}, (error) =>
          debug 'clearAndSaveConfig', @benchmark.toString()
          return callback error if error?

          @setupDevice {flowData, config}, (error) =>
            debug 'setupDevice', @benchmark.toString()
            return callback error if error?
            @flowStatusMessenger.message 'end'
            callback()

  destroy: (callback=->) =>
    @_stop {flowId: @flowUuid}, callback

  _stop: ({flowId}, callback) =>
    @configurationSaver.stop {flowId}, (error) =>
      debug 'configurationSaver.stop', @benchmark.toString()
      return callback error if error?
      @client.del flowId, callback

  clearAndSaveConfig: (options, callback) =>
    {config, stopConfig} = options

    saveOptions =
      flowId: @flowUuid
      version: @version
      flowData: config

    @configurationSaver.saveIotApp callback

  getFlowDevice: (callback) =>
    return callback() if @flowDevice?

    query =
      uuid: @flowUuid

    projection =
      uuid: true
      flow: true

    @meshbluHttp.search query, {projection}, (error, devices) =>
      return callback error if error?
      @flowDevice = _.first devices
      unless @flowDevice?
        error = new Error 'Device Not Found'
        error.code = 404
        return callback error
      unless @flowDevice?.flow
        error = new Error 'Device is missing flow property'
        error.code = 400
        return callback error
      callback null, @flowDevice

  setupDevice: ({flowData, config}, callback=->) =>
    @setupMessageSchema flowData.nodes, callback

  setupMessageSchema: (nodes, callback=->) =>
    triggers = _.filter nodes, class: 'trigger'

    messageSchema =
      type: 'object'
      properties:
        from:
          type: 'string'
          title: 'Trigger'
          required: true
          enum: _.pluck(triggers, 'id')
        payload:
          title: "payload"
          description: "Use {{msg}} to send the entire message"
        replacePayload:
          type: 'string'
          default: 'payload'

    messageFormSchema = [
      { key: 'from', titleMap: @buildFormTitleMap triggers }
      { key: 'payload', 'type': 'input', title: "Payload", description: "Use {{msg}} to send the entire message"}
    ]
    setMessageSchema =
      $set:
        bluprint:
          schemas:
            message:
              default: {messageSchema, messageFormSchema, @instanceId}

    @meshbluHttp.updateDangerously @flowUuid, setMessageSchema, (error) =>
      debug 'setupMessageSchema', @benchmark.toString()
      callback error

module.exports = IotAppPublisher
