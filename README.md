# The JSON-stat Comma-Separated Values Format

[JSON-stat](https://json-stat.org/) is a simple lightweight JSON dissemination format for statistics best suited for data visualizations, mobile apps or open data initiatives.

The **JSON-stat Comma-Separated Values** format (CSV-stat, or JSV for short) is CSV plus an extra metadata header.
CSV-stat supports all the JSON-stat dataset core semantics.

JSON-stat can be converted to CSV-stat and CSV-stat can be converted back to JSON-stat without loss of information (only the [note](https://json-stat.org/format/#note), [link](https://json-stat.org/format/#link), [child](https://json-stat.org/format/#child), [coordinates](https://json-stat.org/format/#coordinates) and [extension](https://json-stat.org/format/#extension) properties in the JSON-stat format are not currently supported by CSV-stat).

***

**Sample file**: https://json-stat.org/samples/galicia.jsv

***

* [The Format](#the-format)
  * [The Extra Metadata Header](#the-extra-metadata-header)
    * [The *jsonstat* line](#the-jsonstat-line)
    * [The *data* line](#the-data-line)
    * [The *href*, *label*, *source* and *updated* lines](#the-href-label-source-and-updated-lines)
    * [The *dimension* lines](#the-dimension-lines)
  * [The CSV Lines](#the-csv-lines)
    * [The CSV header line](#the-csv-header-line)
    * [The CSV data records](#the-csv-data-records)
* [Conversion Tools](#conversion-tools)
  * [Command Line](#command-line)
  * [Client JavaScript](#client-javascript)
  * [Node.js](#nodejs)
* [Importing CSV-stat into Excel](#importing-csv-stat-into-excel)

***

## The Format

### The Extra Metadata Header

CSV-stat adds extra lines at the beginning of a regular CSV file. These extra lines contain metadata organized in columns like in a regular CSV. Like in a regular CSV, the column delimiter is a comma, but can be any character.

The first column in each line of the extra metadata header is the *tag column*. The following columns are *content columns*.

The tag column defines the meaning of the line and can only contain one of the following reserved words:

* *data*
* *dimension*
* *href*
* *jsonstat*
* *label*
* *source*
* *updated*

The first line in the metadata header must be a *jsonstat* line. The last one must be a *data* line. Lines in between can be in any order.

#### The *jsonstat* line

The *jsonstat* line contains two content columns: one for the decimal delimiter and one for the unit separator.

```
jsonstat,.,|
```

(All the examples assume that the column delimiter is the comma.)

#### The *data* line

The *data* line is an empty line: it does not contain any content column.

```
data
```

#### The *href*, *label*, *source* and *updated* lines

These lines are optional. When present, they contain a single content column to store the associated JSON-stat dataset property.

```
label,Unemployment rate in the OECD countries 2003-2014
source,Economic Outlook No 92 - December 2012 - OECD Annual Projections
updated,2012-11-27
href,https://json-stat.org/samples/oecd.json
```

#### The *dimension* lines

There must be as many *dimension* lines as dimensions in the dataset. Order is not important: dimensions will be sorted taking into account the CSV header line.

A *dimension* line must have the following mandatory content columns:

* dimension id
* dimension label
* dimension size (number of categories)

And then for each category:

* category id
* category label

```
dimension,sex,gender,3,T,total,M,male,F,female
```

After that, a *role* column can be optionally included when [role](https://json-stat.org/format/#role) information ("geo", "time", "metric") is available.

```
dimension,residence,province of residence,5,T,total,15,A Coruña,27,Lugo,32,Ourense,36,Pontevedra,geo
```

Dimensions with role "metric" can optionally include a *unit* column for each category in the dimension.

A unit column is made of four possible fields:

1. Number of [decimals](https://json-stat.org/format/#decimals)
2. Unit [label](https://json-stat.org/format/#label)
3. Unit [symbol](https://json-stat.org/format/#symbol)
4. Symbol [position](https://json-stat.org/format/#position)

These fields in the unit column must be delimited with the unit separator specified in the *jsonstat* line. The unit separator (usually, "|") must be different from the column delimiter.

```
dimension,measure,concepts,2,gsp,Gross State Product,pop,population,metric,0|million|$|start,1|million
```

### The CSV Lines

CSV-stat's extra metadata header ends with a *data* line. After that, CSV regular lines are present.

#### The CSV header line

This line must have as many columns as dimensions, plus a *status* column (only when [status](https://json-stat.org/format/#status) information is available), plus a *value* column. Content of these columns in the header line are dimension ids, "status" (when status information is available) and "value".

```
concept,area,year,status,value
```

The order of the columns determines the dimension order. The last column is always the *value* column. When a *status* column is present, it must be immediately before the last one.

#### The CSV data records

Data records follow the header line. Columns contain category ids, status strings (when available) and values. Missing values can be indicated in the *value* column with any string not convertible to a number.

```
UNR,AU,2003,,5.943826289
UNR,AU,2004,m,n/a
UNR,AU,2005,,5.044790587
UNR,AU,2006,,4.789362794
UNR,AU,2007,,4.379649386
UNR,AU,2008,,4.249093453
UNR,AU,2009,,5.592226603
UNR,AU,2010,,5.230660289
UNR,AU,2011,,5.099422942
UNR,AU,2012,,5.224336088
UNR,AU,2013,e,5.50415003
UNR,AU,2014,e,5.462866231
```

Data records order is not relevant. While in a regular CSV, category order must be inferred from the records order, in CSV-stat this information is derived from *dimension* lines.

## Conversion Tools

You can convert between JSON-stat and CSV-stat with the classic [`jsonstat-conv`](https://github.com/jsonstat/conv) CLI and [`jsonstat-suite`](https://www.npmjs.com/package/jsonstat-suite) library, or with the newer, dependency-free [`jsonstat-io`](https://www.npmjs.com/package/jsonstat-io) package ([repo](https://github.com/jsonstat/io)), which works on the command line and in Node and the browser.

### Command Line

Use the [JSON-stat Command Line Conversion Tools](https://github.com/jsonstat/conv) (`jsonstat-conv`) to convert to and from CSV-stat.

To convert to CSV-stat from JSON-stat, use [jsonstat2csv](https://github.com/jsonstat/conv#jsonstat2csv):

```
jsonstat2csv oecd.json oecd.jsv --rich
```

To convert to JSON-stat from CSV-stat, use [csv2jsonstat](https://github.com/jsonstat/conv#csv2jsonstat).

```
csv2jsonstat oecd.jsv oecd.json
```

Alternatively, use the [jsonstat-io](https://github.com/jsonstat/io) CLI:

```
# JSON-stat → CSV-stat
npx jsonstat-io ./oecd.jsonstat.json --to jsv -o oecd.jsv

# CSV-stat → JSON-stat (format auto-detected from the .jsv extension)
npx jsonstat-io ./oecd.jsv
```

### Client JavaScript

Include the [JSON-stat Javascript Toolkit](https://www.npmjs.com/package/jsonstat-toolkit) and the [JSON-stat Javascript Utilities Suite](https://www.npmjs.com/package/jsonstat-suite) in your webpage.

Use [toCSV()](https://github.com/jsonstat/suite/blob/master/docs/tocsv.md) to convert to CSV-stat from JSON-stat.

```js
JSONstat("https://json-stat.org/samples/oecd.json").then(function(json){
  var csv=JSONstatUtils.toCSV(
    json,
    {
      rich: true
    }
  );
  document.getElementsByTagName("body")[0].innerHTML="<pre>"+csv+"</pre>";
});
```

Use [fromCSV()](https://github.com/jsonstat/suite/blob/master/docs/fromcsv.md) to convert to JSON-stat from CSV-stat.

```js
fetch( "https://json-stat.org/samples/galicia.jsv" ).then(function(resp) {
  resp.text().then(function(jsv){
    var json=JSONstatUtils.fromCSV( jsv );
    document.getElementsByTagName("body")[0].innerHTML=JSON.stringify(json);
  });
});
```

Alternatively, the [`jsonstat-io`](https://www.npmjs.com/package/jsonstat-io) package works in the browser as an ES module:

```js
import { exportDataset, importToDataset } from "jsonstat-io";

// JSON-stat → CSV-stat
const jsv = await exportDataset(jsonstatObject, { to: "jsv" });

// CSV-stat → JSON-stat
const jsvString = await (await fetch("https://json-stat.org/samples/galicia.jsv")).text();
const dataset = await importToDataset(jsvString, { from: "jsv" });
```

### Node.js

Use the [jsonstat-suite](https://www.npmjs.com/package/jsonstat-suite) module.

```js
const
  JSONstatUtils = require("jsonstat-suite"),
  csvString = JSONstatUtils.toCSV( jsonstatObject, { rich: true } ),
  newJsonstatObject = JSONstatUtils.fromCSV( csvString )
;
```

Alternatively, use the [`jsonstat-io`](https://www.npmjs.com/package/jsonstat-io) package (ES module):

```js
import { readFile } from "node:fs/promises";
import { exportDataset, importToDataset } from "jsonstat-io";

// JSON-stat → CSV-stat
const jsv = await exportDataset(jsonstatObject, { to: "jsv" });

// CSV-stat → JSON-stat
const dataset = await importToDataset(
  await readFile("./oecd.jsv", "utf8"),
  { from: "jsv" }
);
```

> For lower-level control, the `jsonstat-io/jsv` subpath exposes `csvstatToCube` (parse) and `cubeToCsvstat` (serialize) — see the [jsonstat-io repo](https://github.com/jsonstat/io).

## Importing CSV-stat into Excel

The [`pq/`](pq) folder contains a set of Power Query (M) queries that read a CSV-stat (`.jsv`) file and expose **all** of its information across several related sheets in Excel (Excel for Windows and Mac). Only the built-in Power Query editor is used — no add-ins are required.

### Files

| File | Role | Load it to a sheet? |
|------|------|:-------------------:|
| [`pq/FilePath.pq`](pq/FilePath.pq) | **Parameter** — the absolute path to the `.jsv` file. | Connection only |
| [`pq/CSVStat.pq`](pq/CSVStat.pq) | **Parser** — reads the file, returns a record of 5 tables. | Connection only |
| [`pq/CSVStat_Dataset.pq`](pq/CSVStat_Dataset.pq) | Sheet: dataset properties (label, source, updated, href, separators). | ✅ |
| [`pq/CSVStat_Dimensions.pq`](pq/CSVStat_Dimensions.pq) | Sheet: one row per dimension (id, label, size, role, order). | ✅ |
| [`pq/CSVStat_Categories.pq`](pq/CSVStat_Categories.pq) | Sheet: one row per category (dimension, id, label, order). | ✅ |
| [`pq/CSVStat_Units.pq`](pq/CSVStat_Units.pq) | Sheet: unit info for metric categories (decimals, label, symbol, position). | ✅ |
| [`pq/CSVStat_Data.pq`](pq/CSVStat_Data.pq) | Sheet: the value table (CSV body). `value` is a nullable number. | ✅ |
| [`pq/CSVStat_DataLabeled.pq`](pq/CSVStat_DataLabeled.pq) | Sheet: the value table with dimension **labels** as headers, category **labels** as cell values, plus a decimals-aware `value (formatted)` and `unit` label column. | ✅ |

### How the five sheets relate

```
                         ┌─────────────────────┐
                         │      Dataset        │   single-value properties
                         │ label/source/href…  │
                         └─────────────────────┘

   ┌──────────────┐  DimId   ┌──────────────────┐  DimId+CategoryId   ┌─────────┐
   │  Dimensions  │◄────────│    Categories    │◄─────────────────────│  Units  │
   │ id/size/role │  1 : N   │ cat id/label     │       1 : 1          │ metrics │
   └──────────────┘         └──────────────────┘                      └─────────┘
            ▲
            │ category IDs match the Data columns
            ▼
   ┌──────────────────────────────────────────┐
   │                 Data                     │
   │ [dim columns…][, status] value(number)   │
   └──────────────────────────────────────────┘
```

- **Dimensions** ↔ **Categories** via `DimId`.
- **Categories** ↔ **Units** via `DimId` + `CategoryId` (only metric dimensions have units).
- **Data** ↔ **Categories** via each dimension's category ID columns.

### Install (Excel for Windows / Mac)

1. Open Excel → **Data** tab → **Get Data** → **Launch Power Query Editor…**.
2. In the editor → **Home** → **Manage Parameters** → **New Parameter**:
   - Name: `FilePath`, Type: *Text*, **Current Value**: the **absolute** path to your `.jsv` file (e.g. `/path/to/galicia.jsv`).
3. **Home** → **New Source** → **Blank Query**. Open **Advanced Editor** and paste the contents of [`pq/CSVStat.pq`](pq/CSVStat.pq). Name the query **`CSVStat`**. *Set its Enable Load = OFF (Connection only).*
4. Repeat for each of the `pq/CSVStat_*.pq` files (one query each, keeping the file name as the query name). Leave **Enable Load = ON** for these.
5. **Close & Load** → the sheets appear in the workbook.

> Re-pointing at another file is just a matter of editing the `FilePath` parameter and refreshing.

### What the parser handles

| CSV-stat feature | Handled |
|------------------|:-------:|
| Custom column / decimal / unit separators (from the `jsonstat` line) | ✅ |
| Quoted metadata fields with embedded commas (`source,"…,…"`) | ✅ |
| `label` / `source` / `updated` / `href` (all optional) | ✅ |
| `dimension` lines in any order — order is derived from the CSV header | ✅ |
| Category ids + labels per dimension | ✅ |
| Optional `role` (geo / time / metric) | ✅ |
| Optional per-category **units** for metrics (`decimals\|label\|symbol\|position`) | ✅ |
| Optional `status` column (passed through as text) | ✅ |
| Missing values / non-numeric strings in the `value` column → `null` | ✅ |
| Blank trailing lines stripped | ✅ |
