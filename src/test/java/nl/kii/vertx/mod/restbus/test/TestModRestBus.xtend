package nl.kii.vertx.mod.restbus.test

import nl.kii.async.annotation.Async
import nl.kii.promise.Task
import nl.kii.vertx.TestVerticle
import nl.kii.vertx.Verticle
import nl.kii.vertx.mod.restbus.Config
import nl.kii.vertx.mod.restbus.ModRestBus
import org.junit.Test

import static org.vertx.testtools.VertxAssert.*

import static extension nl.kii.promise.PromiseExtensions.*
import static extension nl.kii.stream.StreamExtensions.*
import static extension nl.kii.vertx.VerticleExtensions.*

class TestModRestBus extends TestVerticle {
	
	override begin() {
		initialize
		val config = new Config('restbus')
		deployVerticle(ModRestBus.name, config.json)
			.call [ deployVerticle(Echo.name) ]
			.then [ startTests ]
			.onError [ fail('could not deploy: ' + cause.message) ]
			.asTask
	}
	
	@Test
	def void simpleRequest() {
		vertx.createHttpClient => [
			host = 'localhost'
			port = 8888
			getNow('/echo?id=hello&test=3434') [ response |
				if(response.statusCode == 200)
				response.bodyHandler [
					assertEquals('{"id":"hello","test":"3434"}', toString)
					println('reply: ' + it)
					testComplete
				]
				else fail(response.statusMessage)
			]
		]
	}
	
	@Test
	def void stringRequest() {
		vertx.createHttpClient => [
			host = 'localhost'
			port = 8888
			getNow('/echo?get=hello') [ response |
				if(response.statusCode == 200)
				response.bodyHandler [
					assertEquals('hello', toString)
					println('reply: ' + it)
					testComplete
				]
				else fail(response.statusMessage)
			]
		]
	}

}

class Echo extends Verticle {
	
	@Async def begin(Task task) {
		(vertx.eventBus/'echo')
			.stream
			.onEach [
				println('got: ' + body) 
				reply(body)
			]
		task.complete
	}
	
}
