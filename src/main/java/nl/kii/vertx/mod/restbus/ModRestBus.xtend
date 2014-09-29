package nl.kii.vertx.mod.restbus

import static extension nl.kii.util.DateExtensions.*
import static extension nl.kii.util.IterableExtensions.*
import static extension nl.kii.vertx.json.JsonExtensions.*
import static extension java.net.URLEncoder.*
import java.net.URI
import nl.kii.async.annotation.Async
import nl.kii.promise.Task
import nl.kii.util.Log
import nl.kii.vertx.Verticle
import org.vertx.java.core.http.HttpServer
import org.vertx.java.core.json.JsonObject


import static extension nl.kii.util.LogExtensions.*
import static extension nl.kii.vertx.MessageExtensions.*
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
	
	@Async def begin(Task task) {
		config = new Config(container.config)
		info('starting rest bridge on port ' + config.port)
		
		restServer = vertx.createHttpServer => [
			requestHandler [ request |
				info('handling ' + request.uri)
				val url  = new URI(request.uri)
				val address = url.path.substring(1) // skip the leading slash
				request.bodyHandler [ body |
					// create a handler for replying an error
					val (Throwable)=>void reportError = [ e |
						error('send failed', e)
						request.response => [
							statusCode = 400
							if(e.message != null) statusMessage = e.message.encode('UTF-8')
							end
						]
					]
					// forward the request
					try {
						val query = url.queryParams?.toMap
						val req = if(query.get('get') != null) {
							// are we just passing a string?
							query.get('get')
						} else {
							// or a real json object via querystring params
							val data = if(body.toString.isJsonObject) new JsonObject(body.toString) else new JsonObject
							url.queryParams?.forEach [ data.putValue(key, value) ]
							data
						}
						info [ 'sending to ' + address + ': ' + req ]
						// send the data and respond with the reply
						(vertx.eventBus/address)
							.timeout(config.timeoutMs.ms)
							.send(req)
							.onFail(reportError)
							.onError(reportError)
							.then [ result |
								request.response => [
									headers.add('Content-Type', 'application/json')
									chunked = true
									write(result.body.toString)
									end
								]
							]
					} catch(Exception error) {
						reportError.apply(error)
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
