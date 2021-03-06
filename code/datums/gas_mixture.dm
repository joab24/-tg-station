 /*
What are the archived variables for?
	Calculations are done using the archived variables with the results merged into the regular variables.
	This prevents race conditions that arise based on the order of tile processing.
*/

#define SPECIFIC_HEAT_TOXIN		200
#define SPECIFIC_HEAT_AIR		20
#define SPECIFIC_HEAT_CDO		30
#define HEAT_CAPACITY_CALCULATION(oxygen,carbon_dioxide,nitrogen,toxins) \
	(carbon_dioxide*SPECIFIC_HEAT_CDO + (oxygen+nitrogen)*SPECIFIC_HEAT_AIR + toxins*SPECIFIC_HEAT_TOXIN)

#define MINIMUM_HEAT_CAPACITY	0.0003
#define QUANTIZE(variable)		(round(variable,0.0001))

/datum/gas
	sleeping_agent
		specific_heat = 40

	oxygen_agent_b
		specific_heat = 300

	volatile_fuel
		specific_heat = 30

	var/moles = 0
	var/specific_heat = 0

	var/moles_archived = 0


/datum/gas_mixture
	var/oxygen = 0
	var/carbon_dioxide = 0
	var/nitrogen = 0
	var/toxins = 0

	var/volume = CELL_VOLUME

	var/temperature = 0 //in Kelvin

	var/last_share

	var/list/datum/gas/trace_gases = list()


	var/tmp/oxygen_archived
	var/tmp/carbon_dioxide_archived
	var/tmp/nitrogen_archived
	var/tmp/toxins_archived

	var/tmp/temperature_archived

	var/tmp/fuel_burnt = 0

	//PV=nRT - related procedures
/datum/gas_mixture/proc/heat_capacity()
	var/heat_capacity = HEAT_CAPACITY_CALCULATION(oxygen,carbon_dioxide,nitrogen,toxins)

	if(trace_gases.len)
		for(var/datum/gas/trace_gas in trace_gases)
			heat_capacity += trace_gas.moles*trace_gas.specific_heat
	return heat_capacity


/datum/gas_mixture/proc/heat_capacity_archived()
	var/heat_capacity_archived = HEAT_CAPACITY_CALCULATION(oxygen_archived,carbon_dioxide_archived,nitrogen_archived,toxins_archived)

	if(trace_gases.len)
		for(var/datum/gas/trace_gas in trace_gases)
			heat_capacity_archived += trace_gas.moles_archived*trace_gas.specific_heat
	return heat_capacity_archived


/datum/gas_mixture/proc/total_moles()
	var/moles = oxygen + carbon_dioxide + nitrogen + toxins

	if(trace_gases.len)
		for(var/datum/gas/trace_gas in trace_gases)
			moles += trace_gas.moles
	return moles


/datum/gas_mixture/proc/return_pressure()
	if(volume>0)
		return total_moles()*R_IDEAL_GAS_EQUATION*temperature/volume
	return 0


/datum/gas_mixture/proc/return_temperature()
	return temperature


/datum/gas_mixture/proc/return_volume()
	return max(0, volume)


/datum/gas_mixture/proc/thermal_energy()
	return temperature*heat_capacity()


//Procedures used for very specific events


/datum/gas_mixture/proc/react(atom/dump_location)
	var/reacting = 0 //set to 1 if a notable reaction occured (used by pipe_network)

	if(trace_gases.len > 0)
		if(temperature > 900)
			if(toxins > MINIMUM_HEAT_CAPACITY && carbon_dioxide > MINIMUM_HEAT_CAPACITY)
				var/datum/gas/oxygen_agent_b/trace_gas = locate(/datum/gas/oxygen_agent_b/) in trace_gases
				if(trace_gas)
					var/reaction_rate = min(carbon_dioxide*0.75, toxins*0.25, trace_gas.moles*0.05)

					carbon_dioxide -= reaction_rate
					oxygen += reaction_rate

					trace_gas.moles -= reaction_rate*0.05

					temperature -= (reaction_rate*20000)/heat_capacity()

					reacting = 1

	fuel_burnt = 0
	if(temperature > FIRE_MINIMUM_TEMPERATURE_TO_EXIST)
		//world << "pre [temperature], [oxygen], [toxins]"
		if(fire() > 0)
			reacting = 1
		//world << "post [temperature], [oxygen], [toxins]"

	return reacting

/datum/gas_mixture/proc/fire()
	var/energy_released = 0
	var/old_heat_capacity = heat_capacity()

	var/datum/gas/volatile_fuel/fuel_store = locate(/datum/gas/volatile_fuel/) in trace_gases
	if(fuel_store) //General volatile gas burn
		var/burned_fuel = 0

		if(oxygen < fuel_store.moles)
			burned_fuel = oxygen
			fuel_store.moles -= burned_fuel
			oxygen = 0
		else
			burned_fuel = fuel_store.moles
			oxygen -= fuel_store.moles
			trace_gases -= fuel_store
			fuel_store = null

		energy_released += FIRE_CARBON_ENERGY_RELEASED * burned_fuel
		carbon_dioxide += burned_fuel
		fuel_burnt += burned_fuel

	//Handle plasma burning
	if(toxins > MINIMUM_HEAT_CAPACITY)
		var/plasma_burn_rate = 0
		var/oxygen_burn_rate = 0
		//more plasma released at higher temperatures
		var/temperature_scale
		if(temperature > PLASMA_UPPER_TEMPERATURE)
			temperature_scale = 1
		else
			temperature_scale = (temperature-PLASMA_MINIMUM_BURN_TEMPERATURE)/(PLASMA_UPPER_TEMPERATURE-PLASMA_MINIMUM_BURN_TEMPERATURE)
		if(temperature_scale > 0)
			oxygen_burn_rate = OXYGEN_BURN_RATE_BASE - temperature_scale
			if(oxygen > toxins*PLASMA_OXYGEN_FULLBURN)
				plasma_burn_rate = (toxins*temperature_scale)/PLASMA_BURN_RATE_DELTA
			else
				plasma_burn_rate = (temperature_scale*(oxygen/PLASMA_OXYGEN_FULLBURN))/PLASMA_BURN_RATE_DELTA
			if(plasma_burn_rate > MINIMUM_HEAT_CAPACITY)
				toxins -= plasma_burn_rate
				oxygen -= plasma_burn_rate*oxygen_burn_rate
				carbon_dioxide += plasma_burn_rate

				energy_released += FIRE_PLASMA_ENERGY_RELEASED * (plasma_burn_rate)

				fuel_burnt += (plasma_burn_rate)*(1+oxygen_burn_rate)

	if(energy_released > 0)
		var/new_heat_capacity = heat_capacity()
		if(new_heat_capacity > MINIMUM_HEAT_CAPACITY)
			temperature = (temperature*old_heat_capacity + energy_released)/new_heat_capacity

	return fuel_burnt

/datum/gas_mixture/proc/archive()
	//Update archived versions of variables
	//Returns: 1 in all cases

/datum/gas_mixture/proc/merge(datum/gas_mixture/giver)
	//Merges all air from giver into self. Deletes giver.
	//Returns: 1 on success (no failure cases yet)

/datum/gas_mixture/proc/remove(amount)
	//Proportionally removes amount of gas from the gas_mixture
	//Returns: gas_mixture with the gases removed

/datum/gas_mixture/proc/remove_ratio(ratio)
	//Proportionally removes amount of gas from the gas_mixture
	//Returns: gas_mixture with the gases removed

/datum/gas_mixture/proc/copy_from(datum/gas_mixture/sample)
	//Copies variables from sample

/datum/gas_mixture/proc/share(datum/gas_mixture/sharer)
	//Performs air sharing calculations between two gas_mixtures assuming only 1 boundary length
	//Return: amount of gas exchanged (+ if sharer received)
/datum/gas_mixture/proc/mimic(turf/model)
	//Similar to share(...), except the model is not modified
	//Return: amount of gas exchanged

/datum/gas_mixture/proc/check_turf(turf/model)
	//Returns: 0 if self-check failed or 1 if check passes

/datum/gas_mixture/proc/temperature_mimic(turf/model, conduction_coefficient)

/datum/gas_mixture/proc/temperature_share(datum/gas_mixture/sharer, conduction_coefficient)

/datum/gas_mixture/proc/temperature_turf_share(turf/simulated/sharer, conduction_coefficient)

/datum/gas_mixture/proc/compare(datum/gas_mixture/sample)
	//Compares sample to self to see if within acceptable ranges that group processing may be enabled

/datum/gas_mixture/archive()
	oxygen_archived = oxygen
	carbon_dioxide_archived = carbon_dioxide
	nitrogen_archived =  nitrogen
	toxins_archived = toxins

	if(trace_gases.len)
		for(var/datum/gas/trace_gas in trace_gases)
			trace_gas.moles_archived = trace_gas.moles

	temperature_archived = temperature

	return 1

/datum/gas_mixture/merge(datum/gas_mixture/giver)
	if(!giver)
		return 0

	if(abs(temperature-giver.temperature)>MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = heat_capacity()
		var/giver_heat_capacity = giver.heat_capacity()
		var/combined_heat_capacity = giver_heat_capacity + self_heat_capacity
		if(combined_heat_capacity != 0)
			temperature = (giver.temperature*giver_heat_capacity + temperature*self_heat_capacity)/combined_heat_capacity

	oxygen += giver.oxygen
	carbon_dioxide += giver.carbon_dioxide
	nitrogen += giver.nitrogen
	toxins += giver.toxins

	if(giver.trace_gases.len)
		for(var/datum/gas/trace_gas in giver.trace_gases)
			var/datum/gas/corresponding = locate(trace_gas.type) in trace_gases
			if(!corresponding)
				corresponding = new trace_gas.type()
				trace_gases += corresponding
			corresponding.moles += trace_gas.moles

//	qdel(giver)
	return 1

/datum/gas_mixture/remove(amount)

	var/sum = total_moles()
	amount = min(amount,sum) //Can not take more air than tile has!
	if(amount <= 0)
		return null

	var/datum/gas_mixture/removed = new


	removed.oxygen = QUANTIZE((oxygen/sum)*amount)
	removed.nitrogen = QUANTIZE((nitrogen/sum)*amount)
	removed.carbon_dioxide = QUANTIZE((carbon_dioxide/sum)*amount)
	removed.toxins = QUANTIZE((toxins/sum)*amount)

	oxygen -= removed.oxygen
	nitrogen -= removed.nitrogen
	carbon_dioxide -= removed.carbon_dioxide
	toxins -= removed.toxins

	if(trace_gases.len)
		for(var/datum/gas/trace_gas in trace_gases)
			var/datum/gas/corresponding = new trace_gas.type()
			removed.trace_gases += corresponding

			corresponding.moles = (trace_gas.moles/sum)*amount
			trace_gas.moles -= corresponding.moles

	removed.temperature = temperature

	return removed

/datum/gas_mixture/remove_ratio(ratio)

	if(ratio <= 0)
		return null

	ratio = min(ratio, 1)

	var/datum/gas_mixture/removed = new

	removed.oxygen = QUANTIZE(oxygen*ratio)
	removed.nitrogen = QUANTIZE(nitrogen*ratio)
	removed.carbon_dioxide = QUANTIZE(carbon_dioxide*ratio)
	removed.toxins = QUANTIZE(toxins*ratio)

	oxygen -= removed.oxygen
	nitrogen -= removed.nitrogen
	carbon_dioxide -= removed.carbon_dioxide
	toxins -= removed.toxins

	if(trace_gases.len)
		for(var/datum/gas/trace_gas in trace_gases)
			var/datum/gas/corresponding = new trace_gas.type()
			removed.trace_gases += corresponding

			corresponding.moles = trace_gas.moles*ratio
			trace_gas.moles -= corresponding.moles

	removed.temperature = temperature

	return removed

/datum/gas_mixture/copy_from(datum/gas_mixture/sample)
	oxygen = sample.oxygen
	carbon_dioxide = sample.carbon_dioxide
	nitrogen = sample.nitrogen
	toxins = sample.toxins

	trace_gases.len=null
	if(sample.trace_gases.len > 0)
		for(var/datum/gas/trace_gas in sample.trace_gases)
			var/datum/gas/corresponding = new trace_gas.type()
			trace_gases += corresponding

			corresponding.moles = trace_gas.moles

	temperature = sample.temperature

	return 1

/datum/gas_mixture/check_turf(turf/model, atmos_adjacent_turfs = 4)
	var/delta_oxygen = (oxygen_archived - model.oxygen)/(atmos_adjacent_turfs+1)
	var/delta_carbon_dioxide = (carbon_dioxide_archived - model.carbon_dioxide)/(atmos_adjacent_turfs+1)
	var/delta_nitrogen = (nitrogen_archived - model.nitrogen)/(atmos_adjacent_turfs+1)
	var/delta_toxins = (toxins_archived - model.toxins)/(atmos_adjacent_turfs+1)

	var/delta_temperature = (temperature_archived - model.temperature)

	if(((abs(delta_oxygen) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_oxygen) >= oxygen_archived*MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_carbon_dioxide) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_carbon_dioxide) >= carbon_dioxide_archived*MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_nitrogen) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_nitrogen) >= nitrogen_archived*MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_toxins) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_toxins) >= toxins_archived*MINIMUM_AIR_RATIO_TO_SUSPEND)))
		return 0
	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND)
		return 0

	if(trace_gases.len)
		for(var/datum/gas/trace_gas in trace_gases)
			if(trace_gas.moles_archived > MINIMUM_AIR_TO_SUSPEND*4)
				return 0

	return 1

/datum/gas_mixture/proc/check_turf_total(turf/model)
	var/delta_oxygen = (oxygen - model.oxygen)
	var/delta_carbon_dioxide = (carbon_dioxide - model.carbon_dioxide)
	var/delta_nitrogen = (nitrogen - model.nitrogen)
	var/delta_toxins = (toxins - model.toxins)

	var/delta_temperature = (temperature - model.temperature)

	if(((abs(delta_oxygen) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_oxygen) >= oxygen*MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_carbon_dioxide) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_carbon_dioxide) >= carbon_dioxide*MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_nitrogen) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_nitrogen) >= nitrogen*MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_toxins) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_toxins) >= toxins*MINIMUM_AIR_RATIO_TO_SUSPEND)))
		return 0
	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND)
		return 0

	if(trace_gases.len)
		for(var/datum/gas/trace_gas in trace_gases)
			if(trace_gas.moles > MINIMUM_AIR_TO_SUSPEND*4)
				return 0

	return 1

/datum/gas_mixture/share(datum/gas_mixture/sharer, atmos_adjacent_turfs = 4)
	if(!sharer)	return 0
	var/delta_oxygen = QUANTIZE(oxygen_archived - sharer.oxygen_archived)/(atmos_adjacent_turfs+1)
	var/delta_carbon_dioxide = QUANTIZE(carbon_dioxide_archived - sharer.carbon_dioxide_archived)/(atmos_adjacent_turfs+1)
	var/delta_nitrogen = QUANTIZE(nitrogen_archived - sharer.nitrogen_archived)/(atmos_adjacent_turfs+1)
	var/delta_toxins = QUANTIZE(toxins_archived - sharer.toxins_archived)/(atmos_adjacent_turfs+1)

	var/delta_temperature = (temperature_archived - sharer.temperature_archived)

	var/old_self_heat_capacity = 0
	var/old_sharer_heat_capacity = 0

	var/heat_capacity_self_to_sharer = 0
	var/heat_capacity_sharer_to_self = 0

	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)

		var/delta_air = delta_oxygen+delta_nitrogen
		if(delta_air)
			var/air_heat_capacity = SPECIFIC_HEAT_AIR*delta_air
			if(delta_air > 0)
				heat_capacity_self_to_sharer += air_heat_capacity
			else
				heat_capacity_sharer_to_self -= air_heat_capacity

		if(delta_carbon_dioxide)
			var/carbon_dioxide_heat_capacity = SPECIFIC_HEAT_CDO*delta_carbon_dioxide
			if(delta_carbon_dioxide > 0)
				heat_capacity_self_to_sharer += carbon_dioxide_heat_capacity
			else
				heat_capacity_sharer_to_self -= carbon_dioxide_heat_capacity

		if(delta_toxins)
			var/toxins_heat_capacity = SPECIFIC_HEAT_TOXIN*delta_toxins
			if(delta_toxins > 0)
				heat_capacity_self_to_sharer += toxins_heat_capacity
			else
				heat_capacity_sharer_to_self -= toxins_heat_capacity

		old_self_heat_capacity = heat_capacity()
		old_sharer_heat_capacity = sharer.heat_capacity()

	oxygen -= delta_oxygen
	sharer.oxygen += delta_oxygen

	carbon_dioxide -= delta_carbon_dioxide
	sharer.carbon_dioxide += delta_carbon_dioxide

	nitrogen -= delta_nitrogen
	sharer.nitrogen += delta_nitrogen

	toxins -= delta_toxins
	sharer.toxins += delta_toxins

	var/moved_moles = (delta_oxygen + delta_carbon_dioxide + delta_nitrogen + delta_toxins)
	last_share = abs(delta_oxygen) + abs(delta_carbon_dioxide) + abs(delta_nitrogen) + abs(delta_toxins)

	var/list/trace_types_considered = list()

	if(trace_gases.len)
		for(var/datum/gas/trace_gas in trace_gases)

			var/datum/gas/corresponding = locate(trace_gas.type) in sharer.trace_gases
			var/delta = 0

			if(corresponding)
				delta = QUANTIZE(trace_gas.moles_archived - corresponding.moles_archived)/(atmos_adjacent_turfs+1)
			else
				corresponding = new trace_gas.type()
				sharer.trace_gases += corresponding

				delta = trace_gas.moles_archived/(atmos_adjacent_turfs+1)

			trace_gas.moles -= delta
			corresponding.moles += delta

			if(delta)
				var/individual_heat_capacity = trace_gas.specific_heat*delta
				if(delta > 0)
					heat_capacity_self_to_sharer += individual_heat_capacity
				else
					heat_capacity_sharer_to_self -= individual_heat_capacity

			moved_moles += delta
			last_share += abs(delta)

			trace_types_considered += trace_gas.type


	if(sharer.trace_gases.len)
		for(var/datum/gas/trace_gas in sharer.trace_gases)
			if(trace_gas.type in trace_types_considered) continue
			else
				var/datum/gas/corresponding
				var/delta = 0

				corresponding = new trace_gas.type()
				trace_gases += corresponding

				delta = trace_gas.moles_archived/5

				trace_gas.moles -= delta
				corresponding.moles += delta

				//Guaranteed transfer from sharer to self
				var/individual_heat_capacity = trace_gas.specific_heat*delta
				heat_capacity_sharer_to_self += individual_heat_capacity

				moved_moles += -delta
				last_share += abs(delta)

	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/new_self_heat_capacity = old_self_heat_capacity + heat_capacity_sharer_to_self - heat_capacity_self_to_sharer
		var/new_sharer_heat_capacity = old_sharer_heat_capacity + heat_capacity_self_to_sharer - heat_capacity_sharer_to_self

		if(new_self_heat_capacity > MINIMUM_HEAT_CAPACITY)
			temperature = (old_self_heat_capacity*temperature - heat_capacity_self_to_sharer*temperature_archived + heat_capacity_sharer_to_self*sharer.temperature_archived)/new_self_heat_capacity

		if(new_sharer_heat_capacity > MINIMUM_HEAT_CAPACITY)
			sharer.temperature = (old_sharer_heat_capacity*sharer.temperature-heat_capacity_sharer_to_self*sharer.temperature_archived + heat_capacity_self_to_sharer*temperature_archived)/new_sharer_heat_capacity

			if(abs(old_sharer_heat_capacity) > MINIMUM_HEAT_CAPACITY)
				if(abs(new_sharer_heat_capacity/old_sharer_heat_capacity - 1) < 0.10) // <10% change in sharer heat capacity
					temperature_share(sharer, OPEN_HEAT_TRANSFER_COEFFICIENT)

	if((delta_temperature > MINIMUM_TEMPERATURE_TO_MOVE) || abs(moved_moles) > MINIMUM_MOLES_DELTA_TO_MOVE)
		var/delta_pressure = temperature_archived*(total_moles() + moved_moles) - sharer.temperature_archived*(sharer.total_moles() - moved_moles)
		return delta_pressure*R_IDEAL_GAS_EQUATION/volume

/datum/gas_mixture/mimic(turf/model, border_multiplier, atmos_adjacent_turfs = 4)
	var/delta_oxygen = QUANTIZE(oxygen_archived - model.oxygen)/(atmos_adjacent_turfs+1)
	var/delta_carbon_dioxide = QUANTIZE(carbon_dioxide_archived - model.carbon_dioxide)/(atmos_adjacent_turfs+1)
	var/delta_nitrogen = QUANTIZE(nitrogen_archived - model.nitrogen)/(atmos_adjacent_turfs+1)
	var/delta_toxins = QUANTIZE(toxins_archived - model.toxins)/(atmos_adjacent_turfs+1)

	var/delta_temperature = (temperature_archived - model.temperature)

	var/heat_transferred = 0
	var/old_self_heat_capacity = 0
	var/heat_capacity_transferred = 0

	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)

		var/delta_air = delta_oxygen+delta_nitrogen
		if(delta_air)
			var/air_heat_capacity = SPECIFIC_HEAT_AIR*delta_air
			heat_transferred -= air_heat_capacity*model.temperature
			heat_capacity_transferred -= air_heat_capacity

		if(delta_carbon_dioxide)
			var/carbon_dioxide_heat_capacity = SPECIFIC_HEAT_CDO*delta_carbon_dioxide
			heat_transferred -= carbon_dioxide_heat_capacity*model.temperature
			heat_capacity_transferred -= carbon_dioxide_heat_capacity

		if(delta_toxins)
			var/toxins_heat_capacity = SPECIFIC_HEAT_TOXIN*delta_toxins
			heat_transferred -= toxins_heat_capacity*model.temperature
			heat_capacity_transferred -= toxins_heat_capacity

		old_self_heat_capacity = heat_capacity()

	if(border_multiplier)
		oxygen -= delta_oxygen*border_multiplier
		carbon_dioxide -= delta_carbon_dioxide*border_multiplier
		nitrogen -= delta_nitrogen*border_multiplier
		toxins -= delta_toxins*border_multiplier
	else
		oxygen -= delta_oxygen
		carbon_dioxide -= delta_carbon_dioxide
		nitrogen -= delta_nitrogen
		toxins -= delta_toxins

	var/moved_moles = (delta_oxygen + delta_carbon_dioxide + delta_nitrogen + delta_toxins)
	last_share = abs(delta_oxygen) + abs(delta_carbon_dioxide) + abs(delta_nitrogen) + abs(delta_toxins)

	if(trace_gases.len)
		for(var/datum/gas/trace_gas in trace_gases)
			var/delta = 0

			delta = trace_gas.moles_archived/(atmos_adjacent_turfs+1)

			if(border_multiplier)
				trace_gas.moles -= delta*border_multiplier
			else
				trace_gas.moles -= delta

			var/heat_cap_transferred = delta*trace_gas.specific_heat
			heat_transferred += heat_cap_transferred*temperature_archived
			heat_capacity_transferred += heat_cap_transferred
			moved_moles += delta
			moved_moles += abs(delta)

	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/new_self_heat_capacity = old_self_heat_capacity - heat_capacity_transferred
		if(new_self_heat_capacity > MINIMUM_HEAT_CAPACITY)
			if(border_multiplier)
				temperature = (old_self_heat_capacity*temperature - heat_capacity_transferred*border_multiplier*temperature_archived)/new_self_heat_capacity
			else
				temperature = (old_self_heat_capacity*temperature - heat_capacity_transferred*temperature_archived)/new_self_heat_capacity

		temperature_mimic(model, model.thermal_conductivity, border_multiplier)

	if((delta_temperature > MINIMUM_TEMPERATURE_TO_MOVE) || abs(moved_moles) > MINIMUM_MOLES_DELTA_TO_MOVE)
		var/delta_pressure = temperature_archived*(total_moles() + moved_moles) - model.temperature*(model.oxygen+model.carbon_dioxide+model.nitrogen+model.toxins)
		return delta_pressure*R_IDEAL_GAS_EQUATION/volume
	else
		return 0

/datum/gas_mixture/temperature_share(datum/gas_mixture/sharer, conduction_coefficient)

	var/delta_temperature = (temperature_archived - sharer.temperature_archived)
	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = heat_capacity_archived()
		var/sharer_heat_capacity = sharer.heat_capacity_archived()

		if((sharer_heat_capacity > MINIMUM_HEAT_CAPACITY) && (self_heat_capacity > MINIMUM_HEAT_CAPACITY))
			var/heat = conduction_coefficient*delta_temperature* \
				(self_heat_capacity*sharer_heat_capacity/(self_heat_capacity+sharer_heat_capacity))

			temperature -= heat/self_heat_capacity
			sharer.temperature += heat/sharer_heat_capacity

/datum/gas_mixture/temperature_mimic(turf/model, conduction_coefficient, border_multiplier)
	var/delta_temperature = (temperature - model.temperature)
	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = heat_capacity()//_archived()

		if((model.heat_capacity > MINIMUM_HEAT_CAPACITY) && (self_heat_capacity > MINIMUM_HEAT_CAPACITY))
			var/heat = conduction_coefficient*delta_temperature* \
				(self_heat_capacity*model.heat_capacity/(self_heat_capacity+model.heat_capacity))

			if(border_multiplier)
				temperature -= heat*border_multiplier/self_heat_capacity
			else
				temperature -= heat/self_heat_capacity

/datum/gas_mixture/temperature_turf_share(turf/simulated/sharer, conduction_coefficient)
	var/delta_temperature = (temperature_archived - sharer.temperature)
	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = heat_capacity()

		if((sharer.heat_capacity > MINIMUM_HEAT_CAPACITY) && (self_heat_capacity > MINIMUM_HEAT_CAPACITY))
			var/heat = conduction_coefficient*delta_temperature* \
				(self_heat_capacity*sharer.heat_capacity/(self_heat_capacity+sharer.heat_capacity))

			temperature -= heat/self_heat_capacity
			sharer.temperature += heat/sharer.heat_capacity

/datum/gas_mixture/compare(datum/gas_mixture/sample)
	if((abs(oxygen-sample.oxygen) > MINIMUM_AIR_TO_SUSPEND) && \
		((oxygen < (1-MINIMUM_AIR_RATIO_TO_SUSPEND)*sample.oxygen) || (oxygen > (1+MINIMUM_AIR_RATIO_TO_SUSPEND)*sample.oxygen)))
		return 0
	if((abs(nitrogen-sample.nitrogen) > MINIMUM_AIR_TO_SUSPEND) && \
		((nitrogen < (1-MINIMUM_AIR_RATIO_TO_SUSPEND)*sample.nitrogen) || (nitrogen > (1+MINIMUM_AIR_RATIO_TO_SUSPEND)*sample.nitrogen)))
		return 0
	if((abs(carbon_dioxide-sample.carbon_dioxide) > MINIMUM_AIR_TO_SUSPEND) && \
		((carbon_dioxide < (1-MINIMUM_AIR_RATIO_TO_SUSPEND)*sample.carbon_dioxide) || (oxygen > (1+MINIMUM_AIR_RATIO_TO_SUSPEND)*sample.carbon_dioxide)))
		return 0
	if((abs(toxins-sample.toxins) > MINIMUM_AIR_TO_SUSPEND) && \
		((toxins < (1-MINIMUM_AIR_RATIO_TO_SUSPEND)*sample.toxins) || (toxins > (1+MINIMUM_AIR_RATIO_TO_SUSPEND)*sample.toxins)))
		return 0

	if(total_moles() > MINIMUM_AIR_TO_SUSPEND)
		if((abs(temperature-sample.temperature) > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND) && \
			((temperature < (1-MINIMUM_TEMPERATURE_RATIO_TO_SUSPEND)*sample.temperature) || (temperature > (1+MINIMUM_TEMPERATURE_RATIO_TO_SUSPEND)*sample.temperature)))
			//world << "temp fail [temperature] & [sample.temperature]"
			return 0

	if(sample.trace_gases.len)
		for(var/datum/gas/trace_gas in sample.trace_gases)
			if(trace_gas.moles_archived > MINIMUM_AIR_TO_SUSPEND)
				var/datum/gas/corresponding = locate(trace_gas.type) in trace_gases
				if(corresponding)
					if((abs(trace_gas.moles - corresponding.moles) > MINIMUM_AIR_TO_SUSPEND) && \
						((corresponding.moles < (1-MINIMUM_AIR_RATIO_TO_SUSPEND)*trace_gas.moles) || (corresponding.moles > (1+MINIMUM_AIR_RATIO_TO_SUSPEND)*trace_gas.moles)))
						return 0
				else
					return 0

	if(trace_gases.len)
		for(var/datum/gas/trace_gas in trace_gases)
			if(trace_gas.moles > MINIMUM_AIR_TO_SUSPEND)
				var/datum/gas/corresponding = locate(trace_gas.type) in sample.trace_gases
				if(corresponding)
					if((abs(trace_gas.moles - corresponding.moles) > MINIMUM_AIR_TO_SUSPEND) && \
						((trace_gas.moles < (1-MINIMUM_AIR_RATIO_TO_SUSPEND)*corresponding.moles) || (trace_gas.moles > (1+MINIMUM_AIR_RATIO_TO_SUSPEND)*corresponding.moles)))
						return 0
				else
					return 0
	return 1




//Takes the amount of the gas you want to PP as an argument
//So I don't have to do some hacky switches/defines/magic strings

//eg:
//Tox_PP = get_partial_pressure(gas_mixture.toxins)
//O2_PP = get_partial_pressure(gas_mixture.oxygen)

//Does handle trace gases!

/datum/gas_mixture/proc/get_breath_partial_pressure(gas_pressure)
	var/breath_pressure = (total_moles()*R_IDEAL_GAS_EQUATION*temperature)/BREATH_VOLUME
	return (gas_pressure/total_moles())*breath_pressure


//Reverse of the above
/datum/gas_mixture/proc/get_true_breath_pressure(breath_pp)
	var/breath_pressure = (total_moles()/R_IDEAL_GAS_EQUATION/temperature)*BREATH_VOLUME
	return (breath_pp/breath_pressure*total_moles())

//Mathematical proofs:
/*

get_breath_partial_pressure(gas_pp) --> gas_pp/total_moles()*breath_pp = pp
get_true_breath_pressure(pp) --> gas_pp = pp/breath_pp*total_moles()

10/20*5 = 2.5
10 = 2.5/5*20

*/
