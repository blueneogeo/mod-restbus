package nl.kii.vertx.mod.restbus

import nl.kii.entity.annotations.Entity
import nl.kii.vertx.json.annotations.Json
import nl.kii.entity.annotations.Require
import java.util.List

@Json @Entity
class Config {
	
	/** the address of this module */
	@Require String address
	
	/** the port the server will be accessible from */
	int port = 8888
	
	/** the maximum time a request may take before timing out */
	int timeoutMs = 20000
	
	/** Cross-origin resource sharing configuration */
	CORS cors
	
	List<String> urlBlacklist
	
}

@Json(strict = false) @Entity
class CORS {
	List<String> allowOrigin
	List<String> allowHeaders
}