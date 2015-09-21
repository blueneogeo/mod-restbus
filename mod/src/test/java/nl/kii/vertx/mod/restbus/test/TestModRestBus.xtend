package nl.kii.vertx.mod.restbus.test

import nl.kii.entity.annotations.Entity
import nl.kii.entity.annotations.Require
import nl.kii.vertx.TestVerticle
import nl.kii.vertx.internal.HttpRequest
import nl.kii.vertx.internal.HttpRequest.Method
import nl.kii.vertx.json.annotations.Json
import nl.kii.vertx.mod.restbus.Config
import nl.kii.vertx.mod.restbus.ModRestBus
import org.junit.Test

import static org.vertx.testtools.VertxAssert.*

import static extension nl.kii.promise.PromiseExtensions.*
import static extension nl.kii.util.DateExtensions.*
import static extension nl.kii.vertx.VerticleExtensions.*
import static extension nl.kii.vertx.VertxExtensions.*
import static extension nl.kii.vertx.VertxHttpExtensions.*
import static extension nl.kii.vertx.json.JsonExtensions.*

class TestModRestBus extends TestVerticle {

	override begin() {
		val config = new Config('restbus')
		deployVerticle(ModRestBus.name, config.json).asTask
	}
	
	@Test
	def void testStringRequest() {
		// setup echo handler
		(vertx.eventBus/'echo').stream.reply;
		// test the restbus to get to echo
		// test the restbus to get to echo
		vertx.load('http://localhost:8888/echo?hello')
			.on(Throwable) [ fail(it) ]
			.then [
				println('reply: ' + it)
				assertEquals('hello', toString)
				testComplete
			]
	}
	
	@Test
	def void testParametersRequest() {
		// setup echo handler
		(vertx.eventBus/'echo').stream.reply;
		// test the restbus to get to echo
		vertx.load('http://localhost:8888/echo?id=hello&test=3434')
			.on(Throwable) [ fail(it) ]
			.then [
				println('reply: ' + it)
				assertEquals('{"test":"3434","id":"hello"}', it)
				testComplete
			]
	}

	@Test
	def void testRawDataRequest() {
		// setup echo handler
		(vertx.eventBus/'echo').stream.reply;
		// test the restbus to get to echo
		val request = new HttpRequest(Method.GET, 'http://localhost:8888/echo') => [
			body = 'hello world!'
		]
		vertx.load(request, 5.secs, 5.secs)
			.on(Throwable) [ fail(it) ]
			.then [
				println('reply: ' + it)
				assertEquals('hello world!', it)
				testComplete
			]
	}
	
	@Test
	def void testJsonFormRequest() {
		// setup echo handler
		(vertx.eventBus/'echo').stream.reply;
		// test the restbus to get to echo
		val request = new HttpRequest(Method.GET, 'http://localhost:8888/echo') => [
			body = #{
				'id' -> 'hello',
				'test' -> '3434'
			}.json.toString
		]
		vertx.load(request, 5.secs, 5.secs)
			.on(Throwable) [ fail(it) ]
			.then [
				println('reply: ' + it)
				assertEquals('{"test":"3434","id":"hello"}', it)
				testComplete
			]
	}

	@Test
	def void testJsonBodyToEntityRequest() {
		// setup echo handler
		(vertx.eventBus/'echo').stream(City).reply;
		// test the restbus to get to echo
		val request = new HttpRequest(Method.POST, 'http://localhost:8888/echo') => [
			
			body = #{
				'name' -> 'Amsterdam',
				'country' -> 'NL'
			}.json.toString
		]
		vertx.load(request)
			.on(Throwable) [ fail(it) ]
			.then [
				println('reply: ' + it)
				assertEquals('{"name":"Amsterdam","country":"NL"}', it)
				testComplete
			]
	}

	
}

@Json @Entity 
class City {
	@Require String name
	@Require String country
		
}