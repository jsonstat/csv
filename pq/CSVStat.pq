// =============================================================================
//  CSVStat  —  PowerQuery (M) parser for the JSON-stat CSV format (CSV-stat / .jsv)
// -----------------------------------------------------------------------------
//  This query reads a .jsv file (path given by the "FilePath" parameter query),
//  splits its metadata header from its CSV body, and returns a RECORD with five
//  ready-to-load tables:
//
//      Dataset    – the single-value properties (label, source, updated, href, …)
//      Dimensions – one row per dimension (id, label, size, role, column order)
//      Categories – one row per category (dimension, category id/label, order)
//      Units      – one row per metric category with unit info (decimals, label,
//                   symbol, position) — only dimensions with role "metric"
//      Data       – the value table, value column typed as nullable number
//
//  The companion queries CSVStat_Dataset / _Dimensions / _Categories / _Units /
//  _Data simply select the matching field of this record and are loaded to
//  worksheets. Keep THIS query as "Connection Only" (do not load it).
//
//  Format reference: see CSV-stat/csv-stat.md
// =============================================================================

let
    /* ---------- 1. Read the file and split it into lines ------------------ *
     *  Line endings are normalised to LF first so the split is deterministic. */
    Bin       = File.Contents(FilePath),
    Raw       = Text.FromBinary(Bin, 65001),                          // UTF-8
    Norm1     = Text.Replace(Raw, "#(cr,lf)", "#(lf)"),
    Norm2     = Text.Replace(Norm1, "#(cr)", "#(lf)"),
    AllLines  = Text.Split(Norm2, "#(lf)"),
    Lines     = List.Select(AllLines, each Text.Trim(_) <> ""),       // drop blanks

    /* ---------- 2. Find the "data" line that closes the metadata header --- *
     *  Everything above it is metadata; everything below it is CSV body.     *
     *  Match is trim- and case-insensitive so trailing whitespace / casing   *
     *  never breaks it.                                                       */
    CleanLines= List.Transform(Lines, each Text.Lower(Text.Trim(_))),
    DataIdx   = List.PositionOf(CleanLines, "data"),
    HeaderLn  = List.FirstN(Lines, DataIdx),
    BodyLn    = List.Skip(Lines, DataIdx + 1),

    /* ---------- 3. Quote-aware CSV splitter for a single line ------------- *
     *  Plain Text.Split would corrupt quoted fields such as                  *
     *  source,"Idescat, a partir del Cens …", so each line is run through    *
     *  Csv.Document which honours standard CSV quoting.                      */
    CsvSplit  = (line as text, delim as text) as list =>
        let
            tbl = Csv.Document(Text.ToBinary(line, 65001),
                    [Delimiter = delim, Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
            vals = Record.FieldValues(tbl{0})
        in
            vals,

    /* ---------- 4. jsonstat line → column delimiter & separators ---------- *
     *  "jsonstat,.,|"  →  column delimiter = the char right after the tag,   *
     *                     decimal separator = ".",  unit separator = "|"     */
    JsLine    = HeaderLn{0},
    // Character right after the "jsonstat" tag is the column delimiter.
    // Text.Middle returns it as text (Text.At returns a code point number).
    ColDelim  = Text.Middle(JsLine, Text.Length("jsonstat"), 1),
    JsFields  = CsvSplit(JsLine, ColDelim),
    DecSep    = JsFields{1},
    UnitSep   = JsFields{2},

    /* ---------- 5. Parse every remaining header line --------------------- */
    Meta      = List.Transform(List.Skip(HeaderLn, 1), each CsvSplit(_, ColDelim)),
    Get1      = (tag as text) as nullable text =>
        let matches = List.Select(Meta, each _{0} = tag)
        in if List.IsEmpty(matches) then null else List.Last(matches){1},
    LabelVal  = Get1("label"),
    SourceVal = Get1("source"),
    UpdatedVal= Get1("updated"),
    HrefVal   = Get1("href"),

    /* ---------- 6. Parse the dimension lines ----------------------------- *
     *  Layout: tag, id, label, size, [catId, catLabel]×size, [role],         *
     *           [unitCol×size]  (units only when role = "metric")            */
    ParseDim  = (f as list) as record =>
        let
            dimId    = f{1},
            dimLabel = f{2},
            size     = Number.From(f{3}),
            c0       = 4,                                              // first category id
            cats     = List.Transform({0..size-1}, each { f{c0 + 2*_}, f{c0 + 2*_ + 1} }),
            baseEnd  = c0 + 2 * size,
            remain   = List.Count(f) - baseEnd,
            role     = if remain >= 1 then f{baseEnd} else null,
            hasUnits = role = "metric" and remain >= 1 + size,
            unitStrs = if hasUnits then List.Transform({0..size-1}, each f{baseEnd + 1 + _}) else {},
            unitRecs = if hasUnits then
                List.Transform({0..size-1}, (i) =>
                    let
                        // unit column = "decimals|label|symbol|position"  (1–4 fields)
                        parts = List.FirstN(Text.Split(unitStrs{i}, UnitSep) & List.Repeat({null}, 4), 4)
                    in
                        [
                            DimId      = dimId,
                            CategoryId = cats{i}{0},
                            Decimals   = try Number.From(parts{0}) otherwise null,
                            UnitLabel  = parts{1},
                            Symbol     = parts{2},
                            Position   = parts{3}
                        ])
                else {}
        in
            [
                DimId = dimId, DimLabel = dimLabel, Size = size, Role = role,
                Cats = cats, Units = unitRecs
            ],
    DimRecs   = List.Transform(List.Select(Meta, each _{0} = "dimension"), ParseDim),

    /* ---------- 7. Dimension column order, taken from the CSV header ------ *
     *  The order of the dimension id columns in the CSV body header defines  *
     *  the canonical dimension order (dimension lines may be in any order).  */
    HdrFields = CsvSplit(BodyLn{0}, ColDelim),
    DimOrder  = List.Select(HdrFields, each _ <> "value" and _ <> "status"),
    PosOf     = (id as text) => List.PositionOf(DimOrder, id),

    /* ---------- 8. Dataset (properties) table ---------------------------- */
    DatasetTbl = #table(
        type table [Property = text, Value = text],
        {
            {"label",            LabelVal},
            {"source",           SourceVal},
            {"updated",          UpdatedVal},
            {"href",             HrefVal},
            {"decimalSeparator", DecSep},
            {"unitSeparator",    UnitSep},
            {"columnDelimiter",  ColDelim},
            {"dimensionCount",   Text.From(List.Count(DimRecs))}
        }),

    /* ---------- 9. Dimensions table -------------------------------------- */
    DimRows     = List.Transform(DimRecs, each
                    [DimId = _[DimId], DimLabel = _[DimLabel], Size = _[Size],
                     Role = _[Role], Order = PosOf(_[DimId])]),
    DimensionsTbl = Table.TransformColumnTypes(
                      Table.Sort(Table.FromRecords(DimRows), {{"Order", Order.Ascending}}),
                      {{"Size", Int64.Type}, {"Order", Int64.Type}}),

    /* ---------- 10. Categories table ------------------------------------- */
    CatRows    = List.Combine(List.Transform(DimRecs, (d) =>
                    List.Transform({0..List.Count(d[Cats])-1}, (i) =>
                        [DimId = d[DimId], CategoryId = d[Cats]{i}{0},
                         CategoryLabel = d[Cats]{i}{1}, Order = i]))),
    CatTbl0    = Table.AddColumn(Table.FromRecords(CatRows), "DimOrder",
                    each PosOf([DimId]), Int64.Type),
    CategoriesTbl = Table.TransformColumnTypes(
                      Table.SelectColumns(
                        Table.Sort(CatTbl0, {{"DimOrder", Order.Ascending}, {"Order", Order.Ascending}}),
                        {"DimId", "CategoryId", "CategoryLabel", "Order"}),
                      {{"Order", Int64.Type}}),

    /* ---------- 11. Units table (metric dimensions only) ----------------- */
    UnitRows   = List.Combine(List.Transform(DimRecs, each _[Units])),
    UnitsTbl0  = if List.IsEmpty(UnitRows)
                    then #table({"DimId","CategoryId","Decimals","UnitLabel","Symbol","Position"}, {})
                    else Table.FromRecords(UnitRows),
    UnitsTbl   = Table.TransformColumnTypes(UnitsTbl0, {{"Decimals", Int64.Type}}),

    /* ---------- 12. Data table (the CSV body) ---------------------------- *
     *  The whole body is fed to Csv.Document; the first row is the header.   *
     *  The "value" column (always last) is converted to a nullable number    *
     *  honouring the declared decimal separator; non-numeric strings         *
     *  (e.g. "n/a") become null.                                             */
    ToNum      = (t) =>
                    if t = null or t = "" then null
                    else let n = Text.Replace(Text.From(t), DecSep, ".")
                         in try Number.From(n, "en-US") otherwise null,
    BodyText   = Text.Combine(BodyLn, "#(cr,lf)"),
    DataRaw    = Csv.Document(Text.ToBinary(BodyText, 65001),
                    [Delimiter = ColDelim, Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    DataProm   = Table.PromoteHeaders(DataRaw, [PromoteAllScalars = true]),
    DataTbl    = Table.TransformColumns(DataProm, {{"value", each ToNum(_), type nullable number}})
in
    [
        Dataset    = DatasetTbl,
        Dimensions = DimensionsTbl,
        Categories = CategoriesTbl,
        Units      = UnitsTbl,
        Data       = DataTbl
    ]
