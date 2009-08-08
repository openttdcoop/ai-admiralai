class AdmiralAI extends AIInfo {
	function GetAuthor()      { return "Thijs Marinussen"; }
	function GetName()        { return "AdmiralAI"; }
	function GetDescription() { return "Some random road-building AI"; }
	function GetVersion()     { return 8; }
	function GetDate()        { return "2008-07-22"; }
	function CreateInstance() { return "AdmiralAI"; }
	function GetSettings() {
		SetSetting({name = "use_busses", description = "Set to 1 to enable busses", min_value = 0, max_value = 1, easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = 0});
		SetSetting({name = "use_trucks", description = "Set to 1 to enable trucks", min_value = 0, max_value = 1, easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = 0});
		SetSetting({name = "build_statues", description = "If set to 1, AdmiralAI will try to build statues as soon as is has enough money", min_value = 0, max_value = 1, easy_value = 0, medium_value = 1, hard_value = 1, custom_value = 1, flags = 0});
	}
};

RegisterAI(AdmiralAI());
