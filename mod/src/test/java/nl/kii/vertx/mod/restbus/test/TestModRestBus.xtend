package nl.kii.vertx.mod.restbus.test

import io.vertx.ext.unit.TestContext
import io.vertx.ext.unit.junit.RunTestOnContext
import io.vertx.ext.unit.junit.VertxUnitRunner
import nl.kii.entity.annotations.Entity
import nl.kii.entity.annotations.Require
import nl.kii.util.PartialURL
import nl.kii.vertx.annotations.Json
import nl.kii.vertx.mod.restbus.Config
import nl.kii.vertx.mod.restbus.ModRestBus
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

import static extension nl.kii.promise.PromiseExtensions.*
import static extension nl.kii.stream.StreamExtensions.*
import static extension nl.kii.vertx.core.VertxExtensions.*
import static extension nl.kii.vertx.json.JsonExtensions.*
import static extension nl.kii.vertx.test.VertxTestExtensions.*

@RunWith(VertxUnitRunner)
class TestModRestBus {

	@Rule public val extension RunTestOnContext rule = new RunTestOnContext
	
	@Before
	def void before(TestContext startup) {
		val config = new Config('restbus')
		
		vertx.deployLocal(ModRestBus.name) [ config = config.json ]
			.completes(startup)
	}
	
	@Test
	def void testStringRequest(TestContext test) {
		// setup echo handler
		(vertx.eventBus/'echo').stream.reply;
		println(new PartialURL('http://localhost:8888/echo?hello'))
		// test the restbus to get to echo
		// test the restbus to get to echo
		vertx.load [ url = 'http://localhost:8888/echo?hello' ]
			.map [ toString ]
			.on(Throwable) [ test.fail(it) ]
			.assertEquals(test, 'hello')
			.completes(test)
	}
	

		
	@Test
	def void testParametersRequest(TestContext test) {
		// setup echo handler
		(vertx.eventBus/'echo').stream.reply;
		// test the restbus to get to echo
		vertx.load [ url = 'http://localhost:8888/echo?id=hello&test=3434' ]
			.on(Throwable) [ test.fail(it) ]
			.map [ toString ]
			.assertEquals(test, '{"test":"3434","id":"hello"}')
			.completes(test)
	}

	@Test
	def void testRawDataRequest(TestContext test) {
		// setup echo handler
		(vertx.eventBus/'echo').stream.reply;
		// test the restbus to get to echo
		vertx.open [ 
				url = 'http://localhost:8888/echo'
				body = 'hello world!'
			]
			.request
			.call [ stream.toBuffer ]
			.map [ toString ]
			.on(Throwable) [ test.fail(it) ]
			.check(test, 'should recognize body') [ it == 'hello world!' ]
	}
	
	@Test
	def void testJsonFormRequest(TestContext test) {
		// setup echo handler
		(vertx.eventBus/'echo').stream.reply;
		// test the restbus to get to echo

		vertx.load [ 
				url = 'http://localhost:8888/echo'
				body = #{ 'id' -> 'hello', 'test' -> '3434' }.json
			]
			.assertEquals(test, '{"test":"3434","id":"hello"}') [ toString ]
			.completes(test)
	}

	@Test
	def void testJsonBodyToEntityRequest(TestContext test) {
		// setup echo handler
		(vertx.eventBus/'echo').stream(City).reply;
		// test the restbus to get to echo
		vertx.load [ 
				url = 'http://localhost:8888/echo'
				body = new City('Amsterdam', 'NL')
			]			
			.assertEquals(test, '{"name":"Amsterdam","country":"NL"}') [ toString ]
			.completes(test)
	}
	
	@Test
	def void testHeaderPropagation(TestContext test) {
		// setup echo handler
		(vertx.eventBus/'echo').stream(City).map [ msg, it | msg.headers.get('Authorization') ].reply;
		// test the restbus to get to echo, header should be returned 
		vertx.load [ 
				url = 'http://localhost:8888/echo'
				body = new City('Amsterdam', 'NL')
				headers.put('Authorization', 'Bearer 123456789')
			]
			.assertEquals(test, 'Bearer 123456789') [ toString ]
			.completes(test)
	}	
	
}

@Json @Entity 
class City {
	@Require String name
	@Require String country
		
}