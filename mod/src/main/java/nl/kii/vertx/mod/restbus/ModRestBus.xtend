package nl.kii.vertx.mod.restbus

import io.vertx.core.http.HttpServer
import io.vertx.core.http.HttpServerRequest
import io.vertx.core.json.JsonObject
import nl.kii.async.annotation.Async
import nl.kii.promise.Task
import nl.kii.util.Log
import nl.kii.util.PartialURL
import nl.kii.vertx.core.Address
import nl.kii.vertx.core.Verticle

import static extension nl.kii.promise.PromiseExtensions.*
import static extension nl.kii.stream.StreamExtensions.*
import static extension nl.kii.util.DateExtensions.*
import static extension nl.kii.util.IterableExtensions.*
import static extension nl.kii.util.LogExtensions.*
import static extension nl.kii.util.OptExtensions.*
import static extension nl.kii.vertx.core.VertxExtensions.*
import static extension nl.kii.vertx.json.JsonExtensions.*

/**
 * Exposes the Vert.x eventbus as a REST resource.
 * <p>
 * Be very careful to restrict access! Security is still a TODO.
 */
class ModRestBus extends Verticle {

	extension Log log = class.logger('restbus').wrapper

	HttpServer restServer

	Config config
	Address address
	
	@Async def begin(Task launch) {
		config = new Config(context.config)
		address = vertx.eventBus/config.address

		info ['starting rest bridge on port ' + config.port]
		
		(address)
			.delivery [ timeout = config.timeoutMs.ms ]
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
						request.response => [
							headers => [
								add('Content-Type', 'application/json; charset=utf-8')
								config.cors.option => [ cors |
									if (!cors.allowHeaders.nullOrEmpty) add('Access-Control-Allow-Headers', cors.allowHeaders)
									if (!cors.allowOrigin.nullOrEmpty) add('Access-Control-Allow-Origin', cors.allowOrigin)
								]
							]
							chunked = true
						]
						
						if (request.method == 'OPTIONS') {
							request.response.end
						}
						
						// get the data from the request
						val data = switch it : url.parameters {
							case request.method == 'POST': {
								switch (it : request.contentType) {
									case !defined, // falls through: request will be treated as application/json
									case value.contains('application/json'): body.toString.json
									case value.contains('text/plain'): body.toString
									case value.contains('application/x-www-form-urlencoded'): throw new UnsupportedOperationException('application/x-www-form-urlencoded requests are currently not supported')
									default: throw new UnsupportedOperationException('''«value» requests are not supported''')
								}
							}
							case null, case empty: {
								body
							}
							case (size == 1 && values.head == ''): {
								url.query
							}
							default: {
								new JsonObject => [ json |
									for(it : toPairs) { json.put(key, value) } 
								]
							} 
						}
						
						val httpHeaders = request.headers.filter [ eventBusHeadersFilter.contains(key) ].list

						info [ 'sending to ' + address + ': ' + data ]
						// send the data and respond with the reply
						(vertx.eventBus/address)
							.delivery [
								timeout = config.timeoutMs.ms
								httpHeaders.forEach [ h | 
									addHeader(h.key, h.value)
								]
							]
							.send(data)
							.on(Throwable) [ request.replyError(it) ]
							.then [ result |
								request.response => [
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
			listen(config.port) [ 
				if (succeeded) {
					info ['successfully started mod-restbus']
					launch.complete
				} 
				else launch.error(cause)
			]
		]
	}
	
	val static eventBusHeadersFilter = #[ 'Authorization' ]
	
	def replyError(HttpServerRequest request, Throwable t) {
		error('error handling request ' + request.uri, t)
		request.response => [
			headers.add('Content-Type', 'application/json')
			chunked = true
			statusCode = 400
			write('''
			{
				"success": false,
				"error": «t.json»
			}
			''')
			end
		]
	}
	
	def static contentType(HttpServerRequest request) {
		val it = request.headers;
		(get('Content-Type') ?: get('Content-type') ?: get('content-type')).option
	}
	
	def isBlacklisted(String url) {
		config.urlBlacklist.findFirst [ url.matches(it) ] != null
	}
		
}