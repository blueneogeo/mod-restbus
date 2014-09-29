# Vert.x Eventbus REST bridge

The Vert.x eventbus is normally hidden away in the network. However for administrating vert.x it can be very useful to have direct REST access to the eventbus.

This module allows you to post rest messages directly to the eventbus. It will try to convert parameters into JSON messages and pass them over the bus.

For example, to deploy twitter stream module using a distributor:

	GET <server>/userstream/start?id=christianvogel
	>> true

Or to perform a TMG get users call:

	GET <server>/telegraaf/get-article?pageSize=100
	>> <list of articles in Json>

This makes all kind of administration and testing a lot easier.

# Security

Of course it is dangerous to simply expose all calls. This is why the allowed calls must be set in the configuration. The configuration is the same as the configuration for the eventbus bridge.