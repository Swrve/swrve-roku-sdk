'Product util constructor'
function SwrveProduct(name as String, id as String, cost as Float, quantity as Integer) as Object
	this = {}
	this.product_id = id
	this.name = name
	this.cost = cost
	this.quantity = quantity	
	return this
end function