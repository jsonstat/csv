// CSVStat_Dimensions — one row per dimension, ordered by their column order
// in the CSV body header. Depends on: CSVStat (connection only), FilePath (parameter).
let
    Result = CSVStat
in
    Result[Dimensions]
