/** @file busline.nut Implementation of BusLine. */

/**
 * Class that controls a line between two bus stops. It can buy and
 *  sell vehicles to keep up with the demand.
 * @todo merge large parts of this class with TruckLine.
 */
class BusLine
{
/* public: */

	/**
	 * Create a new bus line.
	 * @param station_from A StationManager corresponding with the first bus stop.
	 * @param station_to A StationManager corresponding with the second bus stop.
	 * @param depot_tile A TileIndex on which a road depot has been built.
	 * @param cargo The CargoID of the passengers we'll transport.
	 */
	constructor(station_from, station_to, depot_tile, cargo)
	{
		this._station_from = station_from;
		this._station_to = station_to;
		this._vehicle_list = AIList();
		this._depot_tile = depot_tile;
		this._cargo = cargo;
		local station_id_from = station_from.GetStationID();
		local station_id_to = station_to.GetStationID();
		local loc_from = AIStation.GetLocation(station_id_from);
		local loc_to = AIStation.GetLocation(station_id_to);
		local distance = AIMap.DistanceManhattan(loc_from, loc_to);
		local acceptance = AITile.GetCargoAcceptance(loc_from, cargo, 1, 1, AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP));
		acceptance += AITile.GetCargoAcceptance(loc_to, cargo, 1, 1, AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP));
		this.BuildVehicles(max(3, min(20, 2 + ((acceptance / 35) * (distance / 50)).tointeger())));
	}

	/**
	 * Build some new vehicles for this route. First call _FindEngineID()
	 *  so we'll build the best engine available.
	 * @param num The number of vehicles to build.
	 * @return False if and only if the building failed because we didn't
	 *  have enough money.
	 * @note BuildVehicles may return true even if the building failed.
	 */
	function BuildVehicles(num);

	/**
	 * Check if all vehicles on this route are still making a profit. If
	 *  they all do and there are surplus passengers at of the stations,
	 * build some new vehicles.
	 * @return True if and only if we need more money to complete the function.
	 */
	function CheckVehicles();

/* private: */

	/**
	 * A valuator used in _FindEngineID().
	 * @param engine_id The EngineID to valuate.
	 * @return A value for the given EngineID.
	 */
	static function _SortEngineList(engine_id);

	/**
	 * Find the best EngineID for this route. The EngineID is stored
	 *  in this._engine_id.
	 */
	function _FindEngineID();

	_station_from = null; ///< The StationManager managing the source station.
	_station_to = null;   ///< The StationManager managing the station we are transporting cargo to.
	_vehicle_list = null; ///< An AIList() containing all vehicles on this route.
	_depot_tile = null;   ///< A TileIndex indicating the depot that is used by this route (both to build new vehicles and to service existing ones).
	_cargo = null;        ///< The CargoID of the passengers we'll transport.
	_engine_id = null;    ///< The EngineID of the vehicles on this route.
};

function BusLine::BuildVehicles(num)
{
	local max_to_build = min(min(this._station_from.CanAddBusses(num), this._station_to.CanAddBusses(num)), num);
	if (max_to_build == 0) return;
	this._FindEngineID();
	for (local i = 0; i < max_to_build; i++) {
		local v = AIVehicle.BuildVehicle(this._depot_tile, this._engine_id);
		if (!AIVehicle.IsValidVehicle(v)) {
			if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) return false;
			continue;
		}
		AIVehicle.RefitVehicle(v, this._cargo);
		if (this._vehicle_list.Count() > 0) {
			AIOrder.ShareOrders(v, this._vehicle_list.Begin());
		} else {
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_from.GetStationID()), AIOrder.AIOF_NONE);
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_to.GetStationID()), AIOrder.AIOF_NONE);
			AIOrder.AppendOrder(v, this._depot_tile, AIOrder.AIOF_NONE);
			AIOrder.ChangeOrder(v, 2, AIOrder.AIOF_SERVICE_IF_NEEDED);
		}
		if (i % 2) AIVehicle.SkipToVehicleOrder(v, 1);
		this._vehicle_list.AddItem(v, 0);
		this._station_from.AddBusses(1);
		this._station_to.AddBusses(1);
		AIVehicle.StartStopVehicle(v);
	}
	return true;
}

function BusLine::CheckVehicles()
{
	if (this._vehicle_list == null) return;
	local build_new = true;
	local orig_count = this._vehicle_list.Count();
	this._vehicle_list.Valuate(AIVehicle.IsValidVehicle);
	this._vehicle_list.KeepValue(1);
	local valid_count = this._vehicle_list.Count();
	if (valid_count < orig_count) {
		this._station_from.RemoveTrucks(orig_count - valid_count);
		this._station_to.RemoveTrucks(orig_count - valid_count);
	}
	local list = AIList();
	list.AddList(this._vehicle_list);
	list.Valuate(AIVehicle.GetAge);
	list.KeepAboveValue(700);
	list.Valuate(AIVehicle.GetProfitLastYear);
	list.KeepBelowValue(0);

	foreach (v, profit in list) {
		this._vehicle_list.RemoveItem(v);
		AIVehicle.SendVehicleToDepot(v);
		::vehicles_to_sell.AddItem(v, 0);
		this._station_from.RemoveBusses(1);
		this._station_to.RemoveBusses(1);
		build_new = false;
	}

	this._vehicle_list.Valuate(AIVehicle.GetState);
	foreach (vehicle, state in this._vehicle_list) {
		switch (state) {
			case AIVehicle.VS_RUNNING:
				/*local list = AIList();
				list.AddList(this._vehicle_list);
				list.Valuate(BusLineManager._ValuatorReturnItem);
				list.KeepAboveValue(vehicle);*/
				/* Same OrderPosition means same order, since the orders are shared. */
				/*list.Valuate(AIOrder.ResolveOrderPosition, AIOrder.CURRENT_ORDER);
				list.KeepValue(AIOrder.ResolveOrderPosition(vehicle, AIOrder.CURRENT_ORDER));
				local route = RouteFinder.FindRouteBetweenRects(AIVehicle.GetLocation(vehicle), AIOrder.GetOrderDestination(vehicle, AIOrder.CURRENT_ORDER), 0);
				if (route == null) continue;

				list.Valuate(BusLine._VehicleRouteDistanceToTile, AIVehicle.GetLocation(vehicle));
				list.KeepBelowValue(5);
				if (list.Count() > 0) {
					AIVehicle.StartStopVehicle(vehicle);
					build_new = false;
				}*/
				break;

			case AIVehicle.VS_STOPPED:
				AIVehicle.StartStopVehicle(vehicle);
				build_new = false;
				break;

			case AIVehicle.VS_IN_DEPOT:
			case AIVehicle.VS_AT_STATION:
			case AIVehicle.VS_BROKEN:
			case AIVehicle.VS_CRASHED:
				break;
		}
	}

	if (build_new) {
		local cargo_waiting_a = AIStation.GetCargoWaiting(this._station_from.GetStationID(), this._cargo);
		local cargo_waiting_b = AIStation.GetCargoWaiting(this._station_to.GetStationID(), this._cargo);
		local num_new =  0;
		list = AIList();
		list.AddList(this._vehicle_list);
		list.Valuate(AIVehicle.GetAge);
		list.KeepBelowValue(250);
		local num_young_vehicles = list.Count();
		if (max(cargo_waiting_a, cargo_waiting_b) > 100) {
			num_new = max(cargo_waiting_a, cargo_waiting_b) / 60 - max(0, num_young_vehicles);
			num_new = min(num_new, 8); // Don't build more than 8 new vehicles a time.
		}
		local rating = min(AIStation.GetCargoRating(this._station_from.GetStationID(), this._cargo),
		                   AIStation.GetCargoRating(this._station_to.GetStationID(), this._cargo));
		if (rating < 60 && num_young_vehicles == 0 && num_new == 0) num_new = 1;
		if (rating < 45 && num_young_vehicles + num_new <= 1) num_new++;
		if (num_new > 0) this.BuildVehicles(num_new);
	}
}

function BusLine::_SortEngineList(engine_id)
{
	return AIEngine.GetCapacity(engine_id) * AIEngine.GetMaxSpeed(engine_id);
}

function BusLine::_FindEngineID()
{
	local list = AIEngineList(AIVehicle.VEHICLE_ROAD);
	list.Valuate(AIEngine.CanRefitCargo, this._cargo);
	list.KeepValue(1);
	list.Valuate(this._SortEngineList);
	list.Sort(AIAbstractList.SORT_BY_VALUE, false);
	this._engine_id = list.Begin();
}

function BusLine::_VehicleRouteDistanceToTile(vehicle_id, tile)
{
	return AIMap.DistanceManhattan(tile, AIVehicle.GetLocation(vehicle_id));
}
