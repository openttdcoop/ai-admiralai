/** @file townmanager.nut Implementation of TownManager. */

/**
 * Class that manages building multiple bus stations in a town.
 */
class TownManager
{
/* public: */

	/**
	 * Create a new TownManager.
	 * @param town_id The TownID this TownManager is going to manage.
	 */
	constructor(town_id) {
		this._town_id = town_id;
		this._unused_stations = [];
		this._used_stations = [];
		this._depot_tile = null;
		this._station_failed_date = 0;
	}

	/**
	 * Get the TileIndex from a road depot within this town. Build a depot if needed.
	 * @param station_manager The StationManager of the station we want a depot near.
	 * @return The TileIndex of a road depot tile within the town.
	 */
	function GetDepot(station_manager);

	/**
	 * Is it possible to build an extra station within this town?
	 * @return True if and only if an extra bus stop can be build.
	 */
	function CanGetStation();

	/**
	 * Build a new station in the neighbourhood of a given tile.
	 * @param pax_cargo_id The id of the passenger cargo.
	 * @return The StationManager of the newly build station or null if no
	 *  station could be build.
	 */
	function GetStation(pax_cargo_id);

/* private: */

	_town_id = null;             ///< The TownID this TownManager is managing.
	_unused_stations = null;     ///< An array with all StationManagers of unused stations within this town.
	_used_stations = null;       ///< An array with all StationManagers of in use stations within this town.
	_depot_tile = null;          ///< The TileIndex of a road depot tile inside this town.
	_station_failed_date = null; ///< Don't try to build a new station within 60 days of failing to build one.
};

function TownManager::ScanMap()
{
	local station_list = AIStationList(AIStation.STATION_BUS_STOP);
	station_list.Valuate(AIStation.GetNearestTown);
	station_list.KeepValue(this._town_id);

	foreach (station_id, dummy in station_list) {
		local vehicle_list = AIVehicleList_Station(station_id);
		vehicle_list.RemoveList(::vehicles_to_sell);
		if (vehicle_list.Count() > 0) {
			this._used_stations.push(StationManager(station_id, null));
		} else {
			this._unused_stations.push(StationManager(station_id, null));
		}
	}

	local depot_list = AIDepotList(AITile.TRANSPORT_ROAD);
	depot_list.Valuate(AITile.IsWithinTownInfluence, this._town_id);
	depot_list.KeepValue(1);
	depot_list.Valuate(AIMap.DistanceManhattan, AITown.GetLocation(this._town_id));
	depot_list.Sort(AIAbstractList.SORT_BY_VALUE, true);
	if (depot_list.Count() > 0) this._depot_tile = depot_list.Begin();
}

function TownManager::UseStation(station)
{
	foreach (idx, st in this._unused_stations)
	{
		if (st == station) {
			this._unused_stations.remove(idx);
			this._used_stations.push(station);
			return;
		}
	}
	throw("Trying to use a station that doesn't belong to this town!");
}

function TownManager::GetDepot(station_manager)
{
	if (this._depot_tile == null) {
		local stationtiles = AITileList_StationType(station_manager.GetStationID(), AIStation.STATION_BUS_STOP);
		stationtiles.Valuate(AIRoad.GetRoadStationFrontTile);
		this._depot_tile =  AdmiralAI.BuildDepot(stationtiles.GetValue(stationtiles.Begin()));
	}
	return this._depot_tile;
}

function TownManager::CanGetStation()
{
	if (this._unused_stations.len() > 0) return true;
	local rating = AITown.GetRating(this._town_id, AICompany.MY_COMPANY);
	if (rating != AITown.TOWN_RATING_NONE && rating < AITown.TOWN_RATING_MEDIOCRE) return false;
	if (AIDate.GetCurrentDate() - this._station_failed_date < 60) return false;
	if (max(1, (AITown.GetPopulation(this._town_id) / 300).tointeger()) > this._used_stations.len()) return true;
	return false;
}

function TownManager::GetStation(pax_cargo_id)
{
	local town_center = AITown.GetLocation(this._town_id);
	if (this._unused_stations.len() > 0) return this._unused_stations[0];
	/* We need to build a new station. */
	local rating = AITown.GetRating(this._town_id, AICompany.MY_COMPANY);
	if (rating != AITown.TOWN_RATING_NONE && rating < AITown.TOWN_RATING_MEDIOCRE) {
		AILog.Warning("Town rating: " + rating);
		AILog.Warning("Town rating is bad, not going to try building a station in " + AITown.GetName(this._town_id));
		return null;
	}

	local list = AITileList();
	local radius = 10;
	local population = AITown.GetPopulation(this._town_id);
	if (population > 10000) radius += 5;
	if (population > 15000) radius += 5;
	if (population > 25000) radius += 5;
	if (population > 35000) radius += 5;
	if (population > 45000) radius += 5;
	AdmiralAI.AddSquare(list, town_center, radius);
	list.Valuate(AIRoad.GetNeighbourRoadCount);
	list.KeepAboveValue(0);
	list.Valuate(AIRoad.IsRoadTile);
	list.KeepValue(0);
	list.Valuate(AdmiralAI.GetRealHeight);
	list.KeepAboveValue(0);
	list.Valuate(AITile.IsWithinTownInfluence, this._town_id);
	list.KeepValue(1);
	foreach (station in this._used_stations) {
		local station_id = station.GetStationID();
		list.Valuate(AIMap.DistanceSquare, AIStation.GetLocation(station_id));
		list.KeepAboveValue(35);
	}
	list.Valuate(AITile.GetCargoAcceptance, pax_cargo_id, 1, 1, AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP));
	list.KeepAboveValue(25);
	list.Valuate(AIMap.DistanceManhattan, town_center);
	list.Sort(AIAbstractList.SORT_BY_VALUE, true);
	foreach (t, dis in list) {
		if (AICompany.IsMine(AITile.GetOwner(t))) continue;
		local offsets = [AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0, -1),
		                 AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)];
		foreach (offset in offsets) {
			if (!AIRoad.IsRoadTile(t + offset)) continue;
			if (!Utils.IsNearlyFlatTile(t + offset)) continue;
			if (RouteFinder.FindRouteBetweenRects(t + offset, AITown.GetLocation(this._town_id), 0) == null) continue;
			if (!AITile.IsBuildable(t) && !AITile.DemolishTile(t)) continue;
			{
				local testmode = AITestMode();
				if (!AIRoad.BuildRoad(t, t + offset)) continue;
				if (!AIRoad.BuildRoadStation(t, t + offset, false, false, false)) continue;
			}
			if (!AIRoad.BuildRoad(t, t + offset)) continue;
			if (!AIRoad.BuildRoadStation(t, t + offset, false, false, false)) continue;
			local manager = StationManager(AIStation.GetStationID(t), null);
			this._unused_stations.push(manager);
			return manager;
		}
	}
	this._station_failed_date = AIDate.GetCurrentDate();
	AILog.Error("no staton build in " + AITown.GetName(this._town_id));
	return null;
}
