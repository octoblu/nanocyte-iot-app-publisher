_ = require 'lodash'
IotAppPublisher = require '..'

describe 'IotAppPublisher', ->
  describe 'when constructed with a flow', ->

    beforeEach ->
      @configuration = erik_is_happy: true

      options =
        appId: 'the-bluprint-uuid'
        flowId: 'the-flow-uuid'
        appToken: 'the-bluprint-token'
        version: 'some-version'
        client: @client

      @configurationGenerator =
        configure: sinon.stub()

      @configurationSaver =
        saveIotApp: sinon.stub()

      @meshbluHttp =
        message:            sinon.stub()
        updateDangerously:  sinon.stub()
        createSubscription: sinon.stub()
        search:             sinon.stub()

      MeshbluHttp = sinon.spy => @meshbluHttp

      @sut = new IotAppPublisher options,
        configurationGenerator: @configurationGenerator
        configurationSaver: @configurationSaver
        MeshbluHttp: MeshbluHttp

      @meshbluHttp.search.yields null, [draft: { a: 1, b: 5 }]

    describe 'when publish is called', ->
      beforeEach (done)->
        flowConfig =
          'some': 'thing'
          'subscribe-devices':
            config:
              'broadcast.sent': ['subscribe-to-this-uuid']

        @configurationGenerator.configure.yields null, flowConfig, {stop: 'config'}
        @configurationSaver.saveIotApp.yields null
        @meshbluHttp.updateDangerously.yields null
        @sut.publish => done()

      it 'should call configuration generator with the flow', ->
        expect(@configurationGenerator.configure).to.have.been.calledWith
          flowData: { a: 1, b: 5 }
          appToken: 'the-bluprint-token'

      it 'should call configuration saver with the flow', ->
        expect(@configurationSaver.saveIotApp).to.have.been.calledWith(
          appId: 'the-bluprint-uuid'
          version: 'some-version'
          flowData:
            'some': 'thing'
            'subscribe-devices':
              config:
                'broadcast.sent': ['subscribe-to-this-uuid']
        )

      it 'should call meshbluHttp.search', ->
        expect(@meshbluHttp.search).to.have.been.calledWith uuid: 'the-flow-uuid'

    describe 'when publish is called and flow get errored', ->
      beforeEach (done) ->
        @meshbluHttp.search.yields new Error 'whoa, shoots bad', null
        @sut.publish  (@error, @result) => done()

      it 'should call meshbluHttp.search', ->
        expect(@meshbluHttp.search).to.have.been.called

      it 'should yield and error', ->
        expect(@error).to.exist

      it 'should not give us a result', ->
        expect(@result).to.not.exist

    describe 'when publish is called and the configuration generator returns an error', ->
      beforeEach (done)->
        @configurationGenerator.configure.yields new Error 'Oh noes'
        @sut.publish  (@error, @result)=> done()

      it 'should return an error with an error', ->
        expect(@error).to.exist

      it 'should not give us a result', ->
        expect(@result).to.not.exist

    describe 'when publish is called and the configuration save returns an error', ->
      beforeEach (done)->
        @configurationGenerator.configure.yields null, { erik_likes_me: true}
        @configurationSaver.saveIotApp.yields new Error 'Erik can never like me enough'
        @sut.publish  (@error, @result)=> done()

      it 'should yield and error', ->
        expect(@error).to.exist

      it 'should not give us a result', ->
        expect(@result).to.not.exist

    describe 'when publish is called and the generator and saver actually worked', ->
      beforeEach (done) ->
        @configurationGenerator.configure.yields null, { erik_likes_me: 'more than you know'}
        @configurationSaver.saveIotApp.yields null, {finally_i_am_happy: true}
        @sut.setupDevice = sinon.stub().yields null

        @sut.publish  (@error, @result) => done()

      it 'should call setupDeviceForwarding', ->
        expect(@sut.setupDevice).to.have.been.called
