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
import static extension nl.kii.vertx.VerticleExtensions.*
import static extension nl.kii.vertx.VertxExtensions.*
import static extension nl.kii.vertx.VertxHttpExtensions.*

class TestModRestBus extends TestVerticle {
	
	override begin() {
		val config = new Config('restbus')
		complete
			.call [ deployVerticle(ModRestBus.name, config.json) ]
			.call [ deployVerticle(Echo.name) ]
			.asTask
	}
	
	@Test
	def void simpleRequest() {
		vertx.load('http://localhost:8888/echo?id=hello&test=3434')
			.on(Throwable) [ fail(it) ]
			.then [
				assertEquals('{"test":"3434","id":"hello"}', it)
				println('reply: ' + it)
				testComplete
			]
//		
//		
//		vertx.createHttpClient => [
//			host = 'localhost'
//			port = 8888
//			getNow('/echo?id=hello&test=3434') [ response |
//				if(response.statusCode == 200)
//				response.bodyHandler [
//					assertEquals('{"id":"hello","test":"3434"}', toString)
//					println('reply: ' + it)
//					testComplete
//				]
//				else fail(response.statusMessage)
//			]
//		]
	}
	
	@Test
	def void stringRequest() {
		vertx.createHttpClient => [
			host = 'localhost'
			port = 8888
			getNow('/echo?hello') [ response |
				if(response.statusCode == 200)
				response.bodyHandler [
					println('reply: ' + it)
					assertEquals('{"hello":""}', toString)
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
			.reply
		task.complete
	}
	
}
