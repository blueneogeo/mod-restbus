package nl.kii.vertx.mod.restbus

import java.net.URI
import nl.kii.async.annotation.Async
import nl.kii.promise.Task
import nl.kii.util.Log
import nl.kii.util.PartialURL
import nl.kii.vertx.Verticle
import org.vertx.java.core.http.HttpServer
import org.vertx.java.core.http.HttpServerRequest
import org.vertx.java.core.json.JsonObject

import static extension nl.kii.util.DateExtensions.*
import static extension nl.kii.util.IterableExtensions.*
import static extension nl.kii.util.LogExtensions.*
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

	/** Configuration of this distributor */
	Config config
	
	def replyError(HttpServerRequest request, Throwable t) {
		error('error handling request ' + request.uri, t)
		request.response => [
			statusCode = 500
			if(t.message != null) statusMessage = t.message //.encode('UTF-8')
			end
		]
	}
	
	@Async def begin(Task task) {
		config = new Config(container.config)
		info('starting rest bridge on port ' + config.port)
		
		restServer = vertx.createHttpServer => [
			requestHandler [ request |
				// catch errors
				request.exceptionHandler [ 
					error('could not handle request', it)
					request.replyError(it)
				]
				val url  = new PartialURL(request.uri)
				// do not respond a the browser favicon request
				if(url.path == '/favicon.ico') {
					request.response.end
					return
				} 
				info('handling ' + url)
				// create a handler for replying an error
				val address = url.path.substring(1) // skip the leading slash
				request.bodyHandler [ body |
					// forward the request
					try {
						val query = url.parameters
						val req = if(query == null || query.empty) {
							url.query
						} else {
							// or a real json object via querystring params
							val data = if(body.toString.isJsonObject) new JsonObject(body.toString) else new JsonObject
							query.toPairs.forEach [ data.putValue(key, value) ]
							data
						}
						info [ 'sending to ' + address + ': ' + req ]
						// send the data and respond with the reply
						(vertx.eventBus/address)
							.timeout(config.timeoutMs.ms)
							.send(req)
							.onError [ request.replyError(it) ]
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
		
		info('started')
		task.complete
	}
	
	/** 
	 * Create a JSON object like map from the query of a URI
	 * @return the map or null if there was no query
	 */
	def static getQueryParams(URI url) {
		url.query
			?.split('&')
			?.map [ split('=') ]
			?.map [ get(0) -> get(1) ]
	}

}
