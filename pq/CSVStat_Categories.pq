// CSVStat_Categories — one row per category, grouped by dimension and ordered
// as declared in the dimension lines. Depends on: CSVStat, FilePath.
let
    Result = CSVStat
in
    Result[Categories]
