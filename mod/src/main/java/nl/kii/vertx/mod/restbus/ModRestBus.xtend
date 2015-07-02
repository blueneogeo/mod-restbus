package nl.kii.vertx.mod.restbus

import nl.kii.async.annotation.Async
import nl.kii.promise.Task
import nl.kii.util.Log
import nl.kii.util.PartialURL
import nl.kii.vertx.Address
import nl.kii.vertx.Verticle
import org.vertx.java.core.http.HttpServer
import org.vertx.java.core.http.HttpServerRequest
import org.vertx.java.core.json.JsonObject

import static extension nl.kii.promise.PromiseExtensions.*
import static extension nl.kii.stream.StreamExtensions.*
import static extension nl.kii.util.DateExtensions.*
import static extension nl.kii.util.IterableExtensions.*
import static extension nl.kii.util.LogExtensions.*
import static extension nl.kii.vertx.VertxExtensions.*
import static extension nl.kii.vertx.json.JsonExtensions.*
import static extension org.slf4j.LoggerFactory.*

/**
 * Exposes the Vert.x eventbus as a REST resource.
 * <p>
 * Be very careful to restrict access! Security is still a TODO.
 */
class ModRestBus extends Verticle {

	extension Log log = class.logger.wrapper('restbus')

	HttpServer restServer

	Config config
	Address address
	
	def replyError(HttpServerRequest request, Throwable t) {
		error('error handling request ' + request.uri, t)
		request.response => [
			headers.add('Content-Type', 'application/json')
			chunked = true
			statusCode = 200
			write('''
			{
				"success": false,
				"error": «t.json»
			}
			''')
			end
		]
	}
	
	@Async def begin(Task task) {
		config = new Config(container.config)
		info ['starting rest bridge on port ' + config.port]
		
		address = vertx.eventBus/config.address
		address.timeout(config.timeoutMs.ms)
		
		(address)
			.stream
			.map [ this.class.simpleName ]
			.reply;

		(address/'config')
			.stream
			.map [ config.json ]
			.reply;

		restServer = vertx.createHttpServer => [
			requestHandler [ request |
				// catch errors
				request.exceptionHandler [ 
					error('could not handle request', it)
					request.replyError(it)
				]
				if(request.uri.isBlacklisted) {
					request.response.end
					return
				} 
				val url  = new PartialURL(request.uri)
				// do not respond to the browser favicon request
				info('handling ' + url)
				// create a handler for replying an error
				val address = url.path.substring(1) // skip the leading slash
				request.bodyHandler [ body |
					// forward the request
					try {
						val query = url.parameters
						val querydata = if(query == null || query.empty) {
							url.query
						} else {
							// or a real json object via querystring params
							val data = if(body.toString.isJsonObject) new JsonObject(body.toString) else new JsonObject
							query.toPairs.forEach [ data.putValue(key, value) ]
							data
						}
						val data = if(querydata != null) querydata else body
						info [ 'sending to ' + address + ': ' + data ]
						// send the data and respond with the reply
						(vertx.eventBus/address)
							.timeout(config.timeoutMs.ms)
							.send(data)
							.on(Throwable) [ request.replyError(it) ]
							.then [ result |
								request.response => [
									headers.add('Content-Type', 'application/json')
									chunked = true
									write(result.toString)
									end
								]
								info('replied to ' + request.uri)
							]
					} catch(Exception error) {
						request.replyError(error)
					}
				]
			]
			listen(config.port)
		]
		
		info ['started']
		task.complete
	}
	
	def isBlacklisted(String url) {
		config.urlBlacklist.findFirst [ url.matches(it) ] != null
	}
	
}
