#define DUCKDB_EXTENSION_MAIN

#include "gtfs_duck_tools_extension.hpp"
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

static void LoadInternal(ExtensionLoader &loader) {
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

void GtfsDuckToolsExtension::Load(ExtensionLoader &loader) {
	LoadInternal(loader);
}

std::string GtfsDuckToolsExtension::Name() {
	return "gtfs_duck_tools";
}

std::string GtfsDuckToolsExtension::Version() const {
#ifdef EXT_VERSION_GTFS_DUCK_TOOLS
	return EXT_VERSION_GTFS_DUCK_TOOLS;
#else
	return "";
#endif
}

}

extern "C" {

DUCKDB_CPP_EXTENSION_ENTRY(gtfs_duck_tools, loader) {
	duckdb::LoadInternal(loader);
}

}
