// CSVStat_Data — the value table (CSV body). Category IDs are kept raw as in
// the CSV; "value" is typed nullable number (non-numeric strings → null).
// Depends on: CSVStat (connection only), FilePath (parameter).
let
    Result = CSVStat
in
    Result[Data]
