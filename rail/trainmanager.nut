/*
 * This file is part of AdmiralAI.
 *
 * AdmiralAI is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * AdmiralAI is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with AdmiralAI.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Copyright 2008 Thijs Marinussen
 */

/** @file trainmanager.nut Implemenation of TrainManager. */

/**
 * Class that manages all train routes.
 */
class TrainManager
{
/* public: */

	/**
	 * Create a new instance.
	 */
	constructor()
	{
		this._unbuild_routes = {};
		this._ind_to_pickup_stations = {};
		this._ind_to_drop_stations = {};
		this._routes = [];
		this._platform_length = 4;
		this._InitializeUnbuildRoutes();
		AIRail.SetCurrentRailType(0);
	}

	/**
	 * Check all build routes to see if they have the correct amount of trucks.
	 * @return True if and only if we need more money to complete the function.
	 */
	function CheckRoutes();

	/**
	 * Call this function if an industry closed.
	 * @param industry_id The IndustryID of the industry that has closed.
	 */
	function IndustryClose(industry_id);

	/**
	 * Call this function when a new industry was created.
	 * @param industry_id The IndustryID of the new industry.
	 */
	function IndustryOpen(industry_id);

	/**
	 * Build a new cargo route,.
	 * @return True if and only if a new route was created.
	 */
	function BuildNewLine();

/* private: */

	/**
	 * Get a station near an industry. First check if we already have one,
	 *  if so, return it. If there is no station near the industry, try to
	 *  build one.
	 * @param ind The industry to build a station near.
	 * @param producing Boolean indicating whether or not we want to transport
	 *  the cargo to or from the industry.
	 * @param cargo The CargoID we are going to transport.
	 * @return A StationManager if a station was found / could be build or null.
	 */
	function _GetStationNearIndustry(ind, producing, cargo);

	/**
	 * Initialize the array with industries we don't service yet. This
	 * should only be called once before any other function is called.
	 */
	function _InitializeUnbuildRoutes();

	/**
	 * Returns an array with the four tiles adjacent to tile. The array is
	 *  sorted with respect to distance to the tile goal.
	 * @param tile The tile to get the neighbours from.
	 * @param goal The tile we want to be close to.
	 */
	function _GetSortedOffsets(tile, goal);

	_unbuild_routes = null;              ///< A table with as index CargoID and as value an array of industries we haven't connected.
	_ind_to_pickup_stations = null;      ///< A table mapping IndustryIDs to StationManagers. If an IndustryID is not in this list, we haven't build a pickup station there yet.
	_ind_to_drop_stations = null;        ///< A table mapping IndustryIDs to StationManagers.
	_routes = null;                      ///< An array containing all TruckLines build.
	_platform_length = null;
};

function TrainManager::Save()
{
	local data = {pickup_stations = {}, drop_stations = {}, towns_used = [], routes = []};

	foreach (ind, managers in this._ind_to_pickup_stations) {
		local station_ids = [];
		foreach (manager in managers) {
			station_ids.push([manager[0].GetStationID(), manager[1]]);
		}
		data.pickup_stations.rawset(ind, station_ids);
	}

	foreach (ind, managers in this._ind_to_drop_stations) {
		local station_ids = [];
		foreach (manager in managers) {
			station_ids.push([manager[0].GetStationID(), manager[1]]);
		}
		data.drop_stations.rawset(ind, station_ids);
	}

	foreach (route in this._routes) {
		if (!route._valid) continue;
		data.routes.push([route._ind_from, route._station_from.GetStationID(), route._ind_to, route._station_to.GetStationID(), route._depot_tile, route._cargo, route._platform_length]);
	}

	return data;
}

function TrainManager::Load(data)
{
	if (data.rawin("pickup_stations")) {
		foreach (ind, manager_array in data.rawget("pickup_stations")) {
			local new_man_array = [];
			foreach (man_info in manager_array) {
				new_man_array.push([StationManager(man_info[0], this), man_info[1]]);
			}
			this._ind_to_pickup_stations.rawset(ind, new_man_array);
		}
	}

	if (data.rawin("drop_stations")) {
		foreach (ind, manager_array in data.rawget("drop_stations")) {
			local new_man_array = [];
			foreach (man_info in manager_array) {
				new_man_array.push([StationManager(man_info[0], this), man_info[1]]);
			}
			this._ind_to_drop_stations.rawset(ind, new_man_array);
		}
	}

	if (data.rawin("routes")) {
		foreach (route_array in data.rawget("routes")) {
			local station_from = null;
			foreach (station in this._ind_to_pickup_stations.rawget(route_array[0])) {
				if (station[0].GetStationID() == route_array[1]) {
					station_from = station[0];
					break;
				}
			}
			local station_to = null;
			if (this._ind_to_drop_station.rawin(route_array[2])) {
				local station = this._ind_to_drop_station.rawget(route_array[2]);
				if (station.GetStationID() == route_array[3]) {
					station_to = station;
				}
			}
			if (station_from == null || station_to == null) continue;
			local route = TrainLine(route_array[0], station_from, route_array[2], station_to, route_array[4], route_array[5], true, route_array[6]);
			route.ScanPoints();
			this._routes.push(route);
			if (this._unbuild_routes.rawin(route_array[5])) {
			foreach (ind, dummy in this._unbuild_routes[route_array[5]]) {
				if (ind == route_array[0]) {
					AdmiralAI.TransportCargo(route_array[5], ind);
					break;
				}
			}
			} else {
				AILog.Error("CargoID " + route_array[5] + " not in unbuild_routes");
			}
		}
	}
}

function TrainManager::AfterLoad()
{
	foreach (route in this._routes) {
		route._group_id = AIGroup.CreateGroup(AIVehicle.VEHICLE_RAIL);
		route.RenameGroup();
		route.InitiateAutoReplace();
	}
}

function TrainManager::ClosedStation(station)
{
	local ind_station_mapping = this._ind_to_pickup_stations
	if (station.IsCargoDrop()) local ind_station_mapping = this._ind_to_drop_stations;

	foreach (ind, list in ind_station_mapping) {
		local to_remove = [];
		foreach (id, station_pair in list) {
			if (station == station_pair[0]) {
				to_remove.push(id);
			}
		}
		foreach (id in to_remove) {
			list.remove(id);
		}
	}
}

function TrainManager::CheckRoutes()
{
	foreach (route in this._routes) {
		route.CheckVehicles();
	}
	return false;
}

function TrainManager::IndustryClose(industry_id)
{
	for (local i = 0; i < this._routes.len(); i++) {
		local route = this._routes[i];
		if (route.GetIndustryFrom() == industry_id || route.GetIndustryTo() == industry_id) {
			route.CloseRoute();
			this._routes.remove(i);
			i--;
			AILog.Warning("Closed train route");
		}
	}
	foreach (cargo, table in this._unbuild_routes) {
		this._unbuild_routes[cargo].rawdelete(industry_id);
	}
}

function TrainManager::IndustryOpen(industry_id)
{
	AILog.Info("New industry: " + AIIndustry.GetName(industry_id));
	foreach (cargo, dummy in AICargoList_IndustryProducing(industry_id)) {
		if (!this._unbuild_routes.rawin(cargo)) this._unbuild_routes.rawset(cargo, {});
		this._unbuild_routes[cargo].rawset(industry_id, 1);
	}
}

function TrainManager::BuildNewRoute()
{
	local cargo_list = AICargoList();
	/* Try better-earning cargos first. */
	cargo_list.Valuate(AICargo.GetCargoIncome, 80, 40);
	cargo_list.Sort(AIAbstractList.SORT_BY_VALUE, false);

	foreach (cargo, dummy in cargo_list) {
		if (!AICargo.IsFreight(cargo)) continue;
		if (!this._unbuild_routes.rawin(cargo)) continue;
		//TODO: check if there is a wagon + engine available for the current / some rail type
		foreach (ind_from, dummy in this._unbuild_routes.rawget(cargo)) {
			if (AIIndustry.IsBuiltOnWater(ind_from)) continue;
			if (AIIndustry.GetLastMonthProduction(ind_from, cargo) - (AIIndustry.GetLastMonthTransported(ind_from, cargo) >> 1) < 40) {
				if (!AIIndustryType.IsRawIndustry(AIIndustry.GetIndustryType(ind_from))) continue;
			}
			local ind_acc_list = AIIndustryList_CargoAccepting(cargo);
			ind_acc_list.Valuate(AIIndustry.GetDistanceManhattanToTile, AIIndustry.GetLocation(ind_from));
			ind_acc_list.KeepBetweenValue(70, 200);
			ind_acc_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
			foreach (ind_to, dummy in ind_acc_list) {
				local station_from = this._GetStationNearIndustry(ind_from, true, cargo);
				if (station_from == null) break;
				local station_to = this._GetStationNearIndustry(ind_to, false, cargo);
				if (station_to == null) continue;
				local ret = RailRouteBuilder.ConnectRailStations(station_from.GetStationID(), station_to.GetStationID());
				if (typeof(ret) == "array") {
					AILog.Info("Rail route build succesfully");
					local line = TrainLine(ind_from, station_from, ind_to, station_to, ret[0], cargo, false, this._platform_length);
					this._routes.push(line);
					AdmiralAI.TransportCargo(cargo, ind_from);
					this._UsePickupStation(ind_from, station_from);
					this._UseDropStation(ind_to, station_to);
					return true;
				} else {
					AILog.Warning("Error while building rail route: " + ret);
				}
			}
		}
	}
	return false;
}

function TrainManager::TransportCargo(cargo, ind)
{
	this._unbuild_routes[cargo].rawdelete(ind);
}

function TrainManager::_UsePickupStation(ind, station_manager)
{
	foreach (station_pair in this._ind_to_pickup_stations.rawget(ind)) {
		if (station_pair[0] == station_manager) station_pair[1] = true;
	}
}

function TrainManager::_UseDropStation(ind, station_manager)
{
	foreach (station_pair in this._ind_to_drop_stations.rawget(ind)) {
		if (station_pair[0] == station_manager) station_pair[1] = true;
	}
}

function TrainManager::MoveStationTileList(tile, new_list, offset, width, height)
{
	new_list.AddRectangle(tile + offset, tile + offset + AIMap.GetTileIndex(width - 1, height - 1));
	return 0;
}

function TrainManager::_GetStationNearIndustry(ind, producing, cargo)
{
	AILog.Info(AIIndustry.GetName(ind) + " " + producing + " " + cargo);
	if (producing && this._ind_to_pickup_stations.rawin(ind)) {
		foreach (station_pair in this._ind_to_pickup_stations.rawget(ind)) {
			if (!station_pair[1]) return station_pair[0];
		}
	}
	if (!producing && this._ind_to_drop_stations.rawin(ind)) {
		foreach (station_pair in this._ind_to_drop_stations.rawget(ind)) {
			/*if (!station_pair[1])*/ return station_pair[0];
		}
	}

	local platform_length = this._platform_length;

	/* No useable station yet for this industry, so build a new one. */
	local tile_list;
	if (producing) tile_list = AITileList_IndustryProducing(ind, AIStation.GetCoverageRadius(AIStation.STATION_TRAIN));
	else tile_list = AITileList_IndustryAccepting(ind, AIStation.GetCoverageRadius(AIStation.STATION_TRAIN));
	tile_list.Valuate(AdmiralAI.GetRealHeight);
	tile_list.KeepAboveValue(0);
	/* TODO: because two tiles are deleted, we might end up with a station that doesn't accept cargo.
	 * Also we don't build much stations to the north side of industries. */
	if (!producing) {
		tile_list.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1, AIStation.GetCoverageRadius(AIStation.STATION_TRAIN));
		tile_list.KeepAboveValue(7);
	}
	local tile_list2 = AITileList();
	tile_list2.AddList(tile_list);

	local new_tile_list = AITileList();
	tile_list.Valuate(this.MoveStationTileList, new_tile_list, AIMap.GetTileIndex(-1, -platform_length + 1), 2, platform_length - 2);
	tile_list = new_tile_list;

	new_tile_list = AITileList();
	tile_list2.Valuate(this.MoveStationTileList, new_tile_list, AIMap.GetTileIndex(-platform_length + 1, -1), platform_length - 2, 2);
	tile_list2 = new_tile_list;

	{
		local test = AITestMode();
		tile_list.Valuate(AIRail.BuildRailStation, AIRail.RAILTRACK_NW_SE, 2, platform_length + 2, false);
		tile_list.KeepValue(1);
		tile_list2.Valuate(AIRail.BuildRailStation, AIRail.RAILTRACK_NE_SW, 2, platform_length + 2, false);
		tile_list2.KeepValue(1);
	}

	tile_list.Valuate(AIBase.RandItem);
	tile_list.Sort(AIAbstractList.SORT_BY_VALUE, true);
	tile_list2.Valuate(AIBase.RandItem);
	tile_list2.Sort(AIAbstractList.SORT_BY_VALUE, true);

	if (tile_list.Count() == 0) AILog.Warning("No tiles");
	foreach (tile, dummy in tile_list) {
		if (AIRail.BuildRailStation(tile, AIRail.RAILTRACK_NW_SE, 2, platform_length + 2, false)) {
			local manager = StationManager(AIStation.GetStationID(tile), this);
			manager.SetCargoDrop(!producing);
			if (producing) {
				if (!this._ind_to_pickup_stations.rawin(ind)) {
					this._ind_to_pickup_stations.rawset(ind, [[manager, false]]);
				} else {
					this._ind_to_pickup_stations.rawget(ind).push([manager, false]);
				}
			}
			else {
				if (!this._ind_to_drop_stations.rawin(ind)) {
					this._ind_to_drop_stations.rawset(ind, [[manager, false]]);
				} else {
					this._ind_to_drop_stations.rawget(ind).push([manager, false]);
				}
			}
			return manager;
		}
	}
	foreach (tile, dummy in tile_list2) {
		if (AIRail.BuildRailStation(tile, AIRail.RAILTRACK_NE_SW, 2, platform_length + 2, false)) {
			local manager = StationManager(AIStation.GetStationID(tile), this);
			manager.SetCargoDrop(!producing);
			if (producing) {
				if (!this._ind_to_pickup_stations.rawin(ind)) {
					this._ind_to_pickup_stations.rawset(ind, [[manager, false]]);
				} else {
					this._ind_to_pickup_stations.rawget(ind).push([manager, false]);
				}
			}
			else {
				if (!this._ind_to_drop_stations.rawin(ind)) {
					this._ind_to_drop_stations.rawset(ind, [[manager, false]]);
				} else {
					this._ind_to_drop_stations.rawget(ind).push([manager, false]);
				}
			}
			return manager;
		}
	}

	/* @TODO: if building a stations failed, try if we can clear / terraform some tiles for the station. */
	return null;
}

function TrainManager::_InitializeUnbuildRoutes()
{
	local cargo_list = AICargoList();
	foreach (cargo, dummy1 in cargo_list) {
		this._unbuild_routes.rawset(cargo, {});
		local ind_prod_list = AIIndustryList_CargoProducing(cargo);
		foreach (ind, dummy in ind_prod_list) {
			this._unbuild_routes[cargo].rawset(ind, 1);
		}
	}
}