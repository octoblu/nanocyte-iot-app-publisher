Redis                  = require 'ioredis'
mongojs                = require 'mongojs'
Datastore              = require 'meshblu-core-datastore'

MeshbluConfig          = require 'meshblu-config'
ConfigurationSaver     = require 'nanocyte-configuration-saver-redis'
ConfigurationGenerator = require 'nanocyte-configuration-generator'

IotAppPublisher        = require '..'

db                     = mongojs 'localhost/iot-app-publisher-test', ['versions']
datastore              = new Datastore database: db, collection: 'instances'
client                 = new Redis dropBufferSupport: true

meshbluJSON =
  uuid:  '36b038b3-b36e-4fff-b728-9ebbe87dce31'
  token: '578ee84a8c8ae5278e0f8a23582fbcebbe7db8cf'
  server: 'meshblu.octoblu.dev'
  port: '80'

options =
  appId: meshbluJSON.uuid
  appToken: meshbluJSON.token
  version: '1.0.0'
  userUuid: "ab1eb89d-3899-4276-bd31-7c89371105ed"
  userToken: "1b9aa7ddf649cae48f2e6c8c0120a38d53573be9"
  octobluUrl: "http://app.octoblu.dev"
  meshbluConfig: new MeshbluConfig meshbluJSON

class VatChannelConfig
  fetch: (callback) => callback null, {}
  get: => {}
  update: (callback) => callback null

configurationSaver      = new ConfigurationSaver {client, datastore}
configurationGenerator  = new ConfigurationGenerator {meshbluJSON}, {channelConfig: new VatChannelConfig}
iotAppPublisher         = new IotAppPublisher options, {configurationSaver, configurationGenerator}

iotAppPublisher.publish (error, response) =>
  console.log JSON.stringify {error, response}
