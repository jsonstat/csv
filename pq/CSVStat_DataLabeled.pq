// CSVStat_DataLabeled — same rows as CSVStat_Data, but human-readable:
//   * each dimension's category IDs are replaced by their category LABELS
//   * each dimension column header (the dim id) is renamed to the dim LABEL
// Two extra columns are added when unit info is available for the row's
// metric category:
//   * "value (formatted)" — the value rounded to the declared number of
//     decimals, with the unit symbol placed per its position (start/end).
//   * "unit"              — the unit label (e.g. "persons").
// The optional "status" column and the numeric "value" column are passed
// through unchanged. Depends on: CSVStat (connection only), FilePath (parameter).
let
    D          = CSVStat,
    DataTbl    = D[Data],
    Dims       = D[Dimensions],           // already sorted by column order
    Cats       = D[Categories],
    Units      = D[Units],
    DimIds     = Dims[DimId],
    MetricDims = Table.SelectRows(Dims, each [Role] = "metric")[DimId],

    /* ---- 0. Unit lookup keyed by "DimId|CategoryId" -------------------- *
     *  The unit that governs a data row is the unit of the category held    *
     *  by its metric dimension column (looked up on the original ids,       *
     *  before labels are applied below).                                    */
    UnitRecs   = Table.ToRecords(Units),
    UnitLookup = Record.FromList(UnitRecs,
                    List.Transform(UnitRecs, each [DimId] & "|" & [CategoryId])),
    GetUnit    = (row as record) as nullable record =>
        let
            hits = List.RemoveNulls(
                List.Transform(MetricDims, (md) =>
                    Record.FieldOrDefault(UnitLookup, md & "|" & Record.Field(row, md), null)))
        in
            if List.IsEmpty(hits) then null else hits{0},

    /* ---- 1. Formatted value (decimals + symbol) and unit label --------- */
    WithUnit   = Table.AddColumn(DataTbl, "__unit", each GetUnit(_)),
    Formatted  = Table.AddColumn(WithUnit, "value (formatted)", (r) =>
        let
            u = r[__unit],
            v = r[value]
        in
            if v = null then null
            else
                let
                    d      = if u <> null and u[Decimals] <> null then u[Decimals] else null,
                    numTxt = if d <> null
                                then Number.ToText(Number.Round(v, d), "F" & Text.From(d))
                                else Number.ToText(v),
                    sym    = if u <> null then u[Symbol] else null,
                    pos    = if u <> null then u[Position] else null
                in
                    if sym = null or sym = "" then numTxt
                    else if pos = "start" then sym & numTxt
                    else numTxt & sym,
        type text),
    WithLabel  = Table.AddColumn(Formatted, "unit", each
                    let u = [__unit] in if u = null then null else u[UnitLabel], type text),
    NoHelper   = Table.RemoveColumns(WithLabel, {"__unit"}),

    /* ---- 2. Replace category IDs with category labels, per dimension ---- *
     *  A record {CategoryId -> CategoryLabel} gives O(1) lookups; the        *
     *  original id is kept as a fallback if a label is missing.             */
    Labeled    = List.Accumulate(DimIds, NoHelper, (tbl, dim) =>
        let
            catRows = Table.SelectRows(Cats, each [DimId] = dim),
            lookup  = Record.FromList(catRows[CategoryLabel], catRows[CategoryId])
        in
            Table.TransformColumns(tbl,
                {{dim, each Record.FieldOrDefault(lookup, _, _), type text}})),

    /* ---- 3. Rename dimension columns from id to label ------------------ */
    RenameMap  = List.Zip({DimIds, Dims[DimLabel]}),
    Renamed    = Table.RenameColumns(Labeled, RenameMap, MissingField.Ignore)
in
    Renamed
