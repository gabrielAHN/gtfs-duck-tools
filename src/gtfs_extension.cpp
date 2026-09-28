#define DUCKDB_EXTENSION_MAIN

#include "gtfs_extension.hpp"
#include "gtfs_sql.hpp"
#include "duckdb/function/pragma_function.hpp"
#include "duckdb/parser/parser.hpp"
#include "duckdb/parser/statement/create_statement.hpp"
#include "duckdb/parser/parsed_data/create_macro_info.hpp"

namespace duckdb {

static bool IsMacro(SQLStatement &statement) {
	if (statement.type != StatementType::CREATE_STATEMENT) {
		return false;
	}
	auto type = statement.Cast<CreateStatement>().info->type;
	return type == CatalogType::MACRO_ENTRY || type == CatalogType::TABLE_MACRO_ENTRY;
}

static string DatasetStatements(const char *sql) {
	Parser parser;
	parser.ParseQuery(sql);
	string result;
	for (auto &statement : parser.statements) {
		if (!IsMacro(*statement)) {
			result += statement->query + ";\n";
		}
	}
	return result;
}

static string PrepareDataset(ClientContext &, const FunctionParameters &) {
	return DatasetStatements(GTFS_LOAD_SQL);
}

static string InitializeDataset(ClientContext &, const FunctionParameters &) {
	return DatasetStatements(GTFS_LOAD_SQL) + DatasetStatements(GTFS_INIT_SQL);
}

static string normalize_stops(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_STOPS_SQL;
}

static string normalize_pathways(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_PATHWAYS_SQL;
}

static string empty_pathways(ClientContext &, const FunctionParameters &) {
	return GTFS_EMPTY_PATHWAYS_SQL;
}

static string normalize_routes(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_ROUTES_SQL;
}

static string empty_routes(ClientContext &, const FunctionParameters &) {
	return GTFS_EMPTY_ROUTES_SQL;
}

static string normalize_trips(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_TRIPS_SQL;
}

static string empty_trips(ClientContext &, const FunctionParameters &) {
	return GTFS_EMPTY_TRIPS_SQL;
}

static string normalize_stop_times(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_STOP_TIMES_SQL;
}

static string empty_stop_times(ClientContext &, const FunctionParameters &) {
	return GTFS_EMPTY_STOP_TIMES_SQL;
}

static string normalize_shapes(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_SHAPES_SQL;
}

static string empty_shapes(ClientContext &, const FunctionParameters &) {
	return GTFS_EMPTY_SHAPES_SQL;
}

static string normalize_calendar(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_CALENDAR_SQL;
}

static string empty_calendar(ClientContext &, const FunctionParameters &) {
	return GTFS_EMPTY_CALENDAR_SQL;
}

static string normalize_calendar_dates(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_CALENDAR_DATES_SQL;
}

static string empty_calendar_dates(ClientContext &, const FunctionParameters &) {
	return GTFS_EMPTY_CALENDAR_DATES_SQL;
}

static string drop(ClientContext &, const FunctionParameters &) {
	return GTFS_DROP_SQL;
}

static string add_geometry(ClientContext &, const FunctionParameters &) {
	return GTFS_ADD_GEOMETRY_SQL;
}

static string prepare_route_cache(ClientContext &, const FunctionParameters &) {
	return GTFS_PREPARE_ROUTE_CACHE_SQL;
}

static string reset_route_cache(ClientContext &, const FunctionParameters &) {
	return GTFS_RESET_ROUTE_CACHE_SQL;
}

static string route_cache_version(ClientContext &, const FunctionParameters &) {
	return GTFS_ROUTE_CACHE_VERSION_SQL;
}

static void LoadInternal(ExtensionLoader &loader) {
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_prepare_route_cache", prepare_route_cache));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_reset_route_cache", reset_route_cache));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_route_cache_version", route_cache_version));

	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_stops", normalize_stops));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_pathways", normalize_pathways));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_empty_pathways", empty_pathways));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_routes", normalize_routes));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_empty_routes", empty_routes));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_trips", normalize_trips));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_empty_trips", empty_trips));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_stop_times", normalize_stop_times));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_empty_stop_times", empty_stop_times));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_shapes", normalize_shapes));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_empty_shapes", empty_shapes));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_calendar", normalize_calendar));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_empty_calendar", empty_calendar));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_calendar_dates", normalize_calendar_dates));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_empty_calendar_dates", empty_calendar_dates));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_drop", drop));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_add_geometry", add_geometry));

	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_prepare", PrepareDataset));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_init", InitializeDataset));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_refresh", InitializeDataset));
	for (auto sql : {GTFS_LOAD_SQL, GTFS_INIT_SQL, GTFS_REROUTE_SQL}) {
		Parser parser;
		parser.ParseQuery(sql);
		for (auto &statement : parser.statements) {
			if (!IsMacro(*statement)) {
				continue;
			}
			auto &info = statement->Cast<CreateStatement>().info->Cast<CreateMacroInfo>();
			info.schema = DEFAULT_SCHEMA;
			info.internal = true;
			loader.RegisterFunction(info);
		}
	}
}

void GtfsExtension::Load(ExtensionLoader &loader) {
	LoadInternal(loader);
}

std::string GtfsExtension::Name() {
	return "gtfs";
}

std::string GtfsExtension::Version() const {
#ifdef EXT_VERSION_GTFS
	return EXT_VERSION_GTFS;
#else
	return "";
#endif
}

} // namespace duckdb

extern "C" {

DUCKDB_CPP_EXTENSION_ENTRY(gtfs, loader) {
	duckdb::LoadInternal(loader);
}
}
